# Infrastructure

This sets up the base infrastructure that Travigo runs on.

The general k3s worker pool is managed by Cluster Autoscaler and uses Spot
capacity across several x86 instance families. Each pool member is sized at
approximately 8 vCPU and 32 GiB RAM (`m7i.2xlarge`, `m7a.2xlarge`,
`m5.2xlarge`, or `m5d.2xlarge`). Both pools cap Spot bids at $0.20/hour per
instance. `m5d` includes local instance storage, but workloads must not depend
on it because Spot interruption removes that storage.

Batch-import workers use a separate pool with the label
`workload=batch-import` and taint `workload=batch-import:NoSchedule`. Batch
jobs should include the matching node selector and toleration.

Stateful storage workers are pinned to the single AZ selected by
`storage_subnet_id`, with label `workload=storage` and taint
`workload=storage:NoSchedule`. Set it to a subnet in the AZ containing any
existing EBS volumes.

Set these AWS inputs in a non-committed `terraform.tfvars` before applying:

```hcl
vpc_id                 = "vpc-..."
subnet_ids             = ["public-subnet-...", "public-subnet-..."]
storage_subnet_id      = "public-subnet-in-volume-az"
k3s_server_private_ip  = "10.0.0.10"
k3s_token              = "..."
```
