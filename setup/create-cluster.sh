#!/usr/bin/env bash
# Erstellt einen lokalen kind-Cluster für die CNPE-Übungen.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-cnpe}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' existiert bereits."
else
  cd "$SCRIPT_DIR/.."   # extraMounts-Pfade in kind-config.yaml sind relativ zum Repo-Root
  kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml"
fi

kubectl config use-context "kind-$CLUSTER_NAME"

# metrics-server (für kubectl top / HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "✅ Cluster bereit: kind-$CLUSTER_NAME"
kubectl get nodes
