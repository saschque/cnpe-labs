#!/usr/bin/env bash
# Creates a local kind cluster for the CNPE exercises.
set -euo pipefail

# Usage: ./setup/create-cluster.sh [--lite]
#   --lite  single node (control plane only) – for laptops with little RAM
CLUSTER_NAME="${CLUSTER_NAME:-cnpe}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/kind-config.yaml"
if [[ "${1:-}" == "--lite" ]]; then
  CONFIG="$(mktemp)"
  sed '/^  - role: worker/,$d' "$SCRIPT_DIR/kind-config.yaml" > "$CONFIG"   # drop the worker nodes
  echo "ℹ️  Lite mode: single-node cluster"
fi

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists."
else
  cd "$SCRIPT_DIR/.."   # extraMounts paths in kind-config.yaml are relative to the repo root
  kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG"
fi

kubectl config use-context "kind-$CLUSTER_NAME"

# metrics-server (for kubectl top / HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "✅ Cluster ready: kind-$CLUSTER_NAME"
kubectl get nodes
