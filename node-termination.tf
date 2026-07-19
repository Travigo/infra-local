resource "aws_sqs_queue" "node_termination" {
  name                       = "${var.cluster_name}-node-termination"
  message_retention_seconds  = 300
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 120
}

resource "aws_cloudwatch_event_rule" "node_termination" {
  for_each = {
    spot_interruption = {
      detail_types = ["EC2 Spot Instance Interruption Warning"]
      detail       = null
    }
    rebalance = {
      detail_types = ["EC2 Instance Rebalance Recommendation"]
      detail       = null
    }
    instance_state_change = {
      detail_types = ["EC2 Instance State-change Notification"]
      detail = {
        state = ["shutting-down", "terminated", "stopping", "stopped"]
      }
    }
    asg_termination = {
      detail_types = ["EC2 Instance-terminate Lifecycle Action"]
      detail       = null
    }
  }

  name = "${var.cluster_name}-node-termination-${each.key}"

  event_pattern = jsonencode(merge(
    {
      source      = ["aws.ec2", "aws.autoscaling"]
      detail-type = each.value.detail_types
    },
    each.value.detail == null ? {} : { detail = each.value.detail }
  ))
}

resource "aws_cloudwatch_event_target" "node_termination" {
  for_each = aws_cloudwatch_event_rule.node_termination

  rule      = each.value.name
  target_id = "node-termination-queue"
  arn       = aws_sqs_queue.node_termination.arn
}

data "aws_iam_policy_document" "node_termination_queue" {
  dynamic "statement" {
    for_each = aws_cloudwatch_event_rule.node_termination

    content {
      sid       = "AllowEventBridge${replace(title(statement.key), "_", "")}"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.node_termination.arn]

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [statement.value.arn]
      }
    }
  }

  statement {
    sid       = "AllowAutoScalingLifecycleHook"
    effect    = "Allow"
    actions   = ["sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SendMessage"]
    resources = [aws_sqs_queue.node_termination.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.asg_lifecycle_hook.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "node_termination" {
  queue_url = aws_sqs_queue.node_termination.id
  policy    = data.aws_iam_policy_document.node_termination_queue.json
}

data "aws_iam_policy_document" "node_termination_handler" {
  statement {
    sid    = "ProcessTerminationEvents"
    effect = "Allow"

    actions = [
      "autoscaling:CompleteLifecycleAction",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:RecordLifecycleActionHeartbeat",
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ReadTerminationQueue"
    effect = "Allow"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]

    resources = [aws_sqs_queue.node_termination.arn]
  }
}

# K3s does not provide EKS IRSA. NTH therefore uses the EC2 instance role,
# including on the existing kube-node role used by the control-plane host.
resource "aws_iam_role_policy" "node_termination_handler" {
  name   = "${var.cluster_name}-node-termination-handler"
  role   = aws_iam_role.k3s_worker.id
  policy = data.aws_iam_policy_document.node_termination_handler.json
}

resource "aws_iam_role_policy" "node_termination_handler_kube_node" {
  name   = "${var.cluster_name}-node-termination-handler-kube-node"
  role   = data.aws_iam_role.kube_node.id
  policy = data.aws_iam_policy_document.node_termination_handler.json
}

data "aws_iam_policy_document" "asg_lifecycle_hook" {
  statement {
    sid    = "SendLifecycleNotifications"
    effect = "Allow"

    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:SendMessage",
    ]

    resources = [aws_sqs_queue.node_termination.arn]
  }
}

resource "aws_iam_role" "asg_lifecycle_hook" {
  name = "${var.cluster_name}-asg-lifecycle-hook"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "autoscaling.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "asg_lifecycle_hook" {
  name   = "${var.cluster_name}-asg-lifecycle-hook"
  role   = aws_iam_role.asg_lifecycle_hook.id
  policy = data.aws_iam_policy_document.asg_lifecycle_hook.json
}

resource "aws_autoscaling_lifecycle_hook" "node_termination" {
  for_each = {
    general      = aws_autoscaling_group.general.name
    batch_import = aws_autoscaling_group.batch_import.name
    storage      = aws_autoscaling_group.storage.name
  }

  name                    = "${var.cluster_name}-${each.key}-termination"
  autoscaling_group_name  = each.value
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout       = 300
  default_result          = "CONTINUE"
  notification_target_arn = aws_sqs_queue.node_termination.arn
  role_arn                = aws_iam_role.asg_lifecycle_hook.arn

  depends_on = [
    aws_sqs_queue_policy.node_termination,
    aws_iam_role_policy.asg_lifecycle_hook,
  ]
}

resource "helm_release" "node_termination_handler" {
  name       = "aws-node-termination-handler"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/aws-ec2/helm"
  chart      = "aws-node-termination-handler"
  version    = "0.27.0"

  depends_on = [
    aws_iam_role_policy.node_termination_handler,
    aws_iam_role_policy.node_termination_handler_kube_node,
    aws_autoscaling_lifecycle_hook.node_termination,
    aws_cloudwatch_event_target.node_termination,
  ]

  values = [
    yamlencode({
      enableSqsTerminationDraining = true
      queueURL                     = aws_sqs_queue.node_termination.url
      awsRegion                    = var.aws_region
      deleteLocalData              = true
      ignoreDaemonSets             = true
      podTerminationGracePeriod    = 90
      priorityClassName            = "system-cluster-critical"

      nodeSelector = {
        "kubernetes.io/os"                      = "linux"
        "node-role.kubernetes.io/control-plane" = "true"
      }

      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    })
  ]
}
