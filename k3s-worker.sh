#!/bin/bash

set -euo pipefail

install_args="agent"
%{ if node_labels != "" }
install_args="$${install_args} --node-label=${node_labels}"
%{ endif }
%{ if node_taints != "" }
install_args="$${install_args} --node-taint=${node_taints}"
%{ endif }

# Cluster Autoscaler maps Kubernetes Nodes to ASG instances through the AWS
# provider ID. k3s otherwise assigns a k3s:// hostname ID, which makes every
# healthy worker appear unregistered to the AWS cloud provider.
imds_token="$(curl -fsS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)"
imds_header="X-aws-ec2-metadata-token: $${imds_token}"
instance_id="$(curl -fsS -H "$${imds_header}" \
  http://169.254.169.254/latest/meta-data/instance-id)"
availability_zone="$(curl -fsS -H "$${imds_header}" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)"
install_args="$${install_args} --kubelet-arg=provider-id=aws:///$${availability_zone}/$${instance_id}"

export K3S_URL="${k3s_url}"
export K3S_TOKEN="${k3s_token}"
export INSTALL_K3S_EXEC="$${install_args}"

curl -sfL https://get.k3s.io | sh -
