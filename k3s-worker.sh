#!/bin/bash

set -euo pipefail

install_args="agent"
%{ if node_labels != "" }
install_args="$${install_args} --node-label=${node_labels}"
%{ endif }
%{ if node_taints != "" }
install_args="$${install_args} --node-taint=${node_taints}"
%{ endif }

export K3S_URL="${k3s_url}"
export K3S_TOKEN="${k3s_token}"
export INSTALL_K3S_EXEC="$${install_args}"

curl -sfL https://get.k3s.io | sh -
