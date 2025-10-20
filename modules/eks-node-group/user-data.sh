#!/bin/bash
# EKS Node Bootstrap Script
# This script runs on node startup to join the EKS cluster

set -o xtrace

# Bootstrap the node to join the cluster
/etc/eks/bootstrap.sh '${cluster_name}' \
  --b64-cluster-ca '${cluster_ca}' \
  --apiserver-endpoint '${cluster_endpoint}' \
  ${bootstrap_arguments}

# Log completion
echo "EKS node bootstrap completed successfully"
