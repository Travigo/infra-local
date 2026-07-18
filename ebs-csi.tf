data "aws_iam_policy_document" "ebs_csi" {
  statement {
    sid    = "EBSVolumeLifecycle"
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EBSDescribe"
    effect = "Allow"

    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
    ]

    resources = ["*"]
  }
}

# The existing k3s nodes currently use this instance role. Keep the policy on
# it as well as the Terraform-managed worker role so the CSI controller works
# on both existing and newly launched nodes.
data "aws_iam_role" "kube_node" {
  name = "kube-node"
}

# k3s does not provide EKS IRSA, so the CSI controller uses the EC2 instance
# profile shared by worker nodes to call the EC2 APIs above.
resource "aws_iam_role_policy" "ebs_csi" {
  name   = "${var.cluster_name}-ebs-csi"
  role   = aws_iam_role.k3s_worker.id
  policy = data.aws_iam_policy_document.ebs_csi.json
}

resource "aws_iam_role_policy" "ebs_csi_kube_node" {
  name   = "${var.cluster_name}-ebs-csi-kube-node"
  role   = data.aws_iam_role.kube_node.id
  policy = data.aws_iam_policy_document.ebs_csi.json
}

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.62.0"

  depends_on = [
    aws_iam_role_policy.ebs_csi,
    aws_iam_role_policy.ebs_csi_kube_node,
  ]

  values = [
    yamlencode({
      controller = {
        region            = var.aws_region
        priorityClassName = "system-cluster-critical"

        serviceAccount = {
          create = true
          name   = "ebs-csi-controller-sa"
        }
      }

      node = {
        serviceAccount = {
          create = true
          name   = "ebs-csi-node-sa"
        }
      }

      storageClasses = [
        {
          name = "ebs-gp3"
          annotations = {
            "storageclass.kubernetes.io/is-default-class" = "true"
          }
          volumeBindingMode    = "WaitForFirstConsumer"
          reclaimPolicy        = "Delete"
          allowVolumeExpansion = true
          parameters = {
            type      = "gp3"
            encrypted = "true"
            fsType    = "ext4"
          }
        }
      ]
    })
  ]
}
