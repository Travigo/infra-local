resource "kubernetes_priority_class" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler-critical"
  }

  # Higher than normal workloads, but below Kubernetes' built-in
  # system-cluster-critical and system-node-critical classes.
  value             = 1000000000
  global_default    = false
  preemption_policy = "PreemptLowerPriority"
  description       = "Priority for the Cluster Autoscaler control loop"
}

resource "helm_release" "cluster_autoscaler" {
  name      = "cluster-autoscaler"
  namespace = "kube-system"

  depends_on = [kubernetes_priority_class.cluster_autoscaler]

  repository = "https://kubernetes.github.io/autoscaler"

  chart = "cluster-autoscaler"

  values = [
    yamlencode({
      cloudProvider = "aws"

      awsRegion = var.aws_region

      autoDiscovery = {
        clusterName = var.cluster_name
      }

      rbac = {
        create = true
      }

      extraArgs = {
        "balance-similar-node-groups"      = "true"
        "skip-nodes-with-system-pods"      = "false"
        "scale-down-unneeded-time"         = "5m"
        "scale-down-delay-after-add"       = "5m"
        "scale-down-delay-after-delete"    = "5m"
        "scale-down-utilization-threshold" = "0.5"
        # The AWS price expander is not implemented by this autoscaler build.
        "expander" = "least-waste"
      }

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

      priorityClassName = kubernetes_priority_class.cluster_autoscaler.metadata[0].name
    })
  ]
}

data "aws_ami" "al2023" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "general" {
  name_prefix = "${var.cluster_name}-general-"

  image_id = data.aws_ami.al2023.id

  # The ASG supplies the instance type overrides. Keeping a representative
  # type here also gives Cluster Autoscaler a useful template at size zero.
  instance_type = "m7i.2xlarge"

  # Workers need directly routable public addresses. The supplied subnet IDs
  # must therefore reference public subnets with a route to an Internet Gateway.
  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_worker.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k3s_nodes.id]
  }

  user_data = base64encode(
    templatefile("${path.module}/k3s-worker.sh", {
      k3s_url     = "https://${var.k3s_server_private_ip}:6443"
      k3s_token   = var.k3s_token
      node_labels = ""
      node_taints = ""
    })
  )
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "k3s_worker" {
  name               = "${var.cluster_name}-k3s-worker"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "k3s_worker" {
  name = "${var.cluster_name}-k3s-worker"
  role = aws_iam_role.k3s_worker.name
}

resource "aws_iam_role_policy_attachment" "k3s_worker_ssm" {
  role       = aws_iam_role.k3s_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name   = "${var.cluster_name}-cluster-autoscaler"
  role   = aws_iam_role.k3s_worker.id
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

resource "aws_security_group" "k3s_nodes" {
  name        = "${var.cluster_name}-k3s-nodes"
  description = "Security group for k3s worker nodes"
  vpc_id      = var.vpc_id

  # Ingress is managed by standalone aws_security_group_rule resources below.
  # Keep the existing self-rule in place without making this resource revoke
  # rules that may already have changed outside Terraform.
  lifecycle {
    ignore_changes = [ingress]
  }

  ingress {
    description = "k3s node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Worker node outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow all traffic between the k3s server and worker nodes. This covers
# Flannel, the Kubernetes API, kubelet, and future k3s control-plane traffic.
resource "aws_security_group_rule" "k3s_nodes_from_server" {
  type                     = "ingress"
  security_group_id        = aws_security_group.k3s_nodes.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = var.k3s_server_security_group_id
  description              = "All k3s traffic from the server"
}

resource "aws_security_group_rule" "k3s_server_from_nodes" {
  type                     = "ingress"
  security_group_id        = var.k3s_server_security_group_id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.k3s_nodes.id
  description              = "All k3s traffic from workers"
}

resource "aws_autoscaling_group" "general" {
  name = "${var.cluster_name}-general"

  min_size         = 1
  desired_capacity = 0
  max_size         = 20

  vpc_zone_identifier = var.subnet_ids

  capacity_rebalance = true

  health_check_type = "EC2"

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized-prioritized"
      spot_max_price                           = "0.20"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.general.id
        version            = "$Latest"
      }

      # Every option is approximately 8 vCPU / 32 GiB, while spanning
      # families and generations to improve Spot capacity availability.
      override { instance_type = "m7i.2xlarge" }
      override { instance_type = "m7a.2xlarge" }
      override { instance_type = "m5.2xlarge" }
      override { instance_type = "m5d.2xlarge" }
    }
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_launch_template" "batch_import" {
  name_prefix = "${var.cluster_name}-batch-import-"

  image_id = data.aws_ami.al2023.id

  # Keep batch workers the same size as the general pool while allowing
  # Cluster Autoscaler to choose from multiple Spot-capable families.
  instance_type = "m7i.2xlarge"

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_worker.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k3s_nodes.id]
  }

  user_data = base64encode(
    templatefile("${path.module}/k3s-worker.sh", {
      k3s_url     = "https://${var.k3s_server_private_ip}:6443"
      k3s_token   = var.k3s_token
      node_labels = "workload=batch-import"
      node_taints = "workload=batch-import:NoSchedule"
    })
  )
}

resource "aws_autoscaling_group" "batch_import" {
  name = "${var.cluster_name}-batch-import"

  min_size         = 0
  desired_capacity = 0
  max_size         = 20

  vpc_zone_identifier = var.subnet_ids

  capacity_rebalance = true
  health_check_type  = "EC2"

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized-prioritized"
      spot_max_price                           = "0.20"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.batch_import.id
        version            = "$Latest"
      }

      override { instance_type = "m7i.2xlarge" }
      override { instance_type = "m7a.2xlarge" }
      override { instance_type = "m5.2xlarge" }
      override { instance_type = "m5d.2xlarge" }
    }
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  # These tags let Cluster Autoscaler simulate a node when this pool is at
  # zero and select it for pods requesting the batch-import workload.
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/workload"
    value               = "batch-import"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/taint/workload"
    value               = "batch-import:NoSchedule"
    propagate_at_launch = false
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_launch_template" "storage" {
  name_prefix   = "${var.cluster_name}-storage-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "m7i.2xlarge"

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_worker.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k3s_nodes.id]
  }

  user_data = base64encode(
    templatefile("${path.module}/k3s-worker.sh", {
      k3s_url     = "https://${var.k3s_server_private_ip}:6443"
      k3s_token   = var.k3s_token
      node_labels = "workload=storage"
      node_taints = "workload=storage:NoSchedule"
    })
  )
}

resource "aws_autoscaling_group" "storage" {
  name = "${var.cluster_name}-storage"

  min_size         = 1
  desired_capacity = 0
  max_size         = 10

  # A single subnet keeps storage nodes in one AZ, matching the EBS volumes.
  vpc_zone_identifier = [var.storage_subnet_id]

  capacity_rebalance = true
  health_check_type  = "EC2"

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized-prioritized"
      spot_max_price                           = "0.20"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.storage.id
        version            = "$Latest"
      }

      override { instance_type = "m7i.2xlarge" }
      override { instance_type = "m7a.2xlarge" }
      override { instance_type = "m5.2xlarge" }
      override { instance_type = "m5d.2xlarge" }
    }
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/workload"
    value               = "storage"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/taint/workload"
    value               = "storage:NoSchedule"
    propagate_at_launch = false
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
