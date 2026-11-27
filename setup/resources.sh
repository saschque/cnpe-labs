#!/usr/bin/env bash
# Shows what uses your laptop's CPU and memory right now.
echo "== kind nodes (Docker containers)"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' $(kind get nodes --name "${CLUSTER_NAME:-$(kind get clusters | head -1)}" 2>/dev/null) 2>/dev/null
echo
echo "== Top 15 pods by memory"
kubectl top pods -A --sort-by=memory 2>/dev/null | head -16 || echo "(metrics-server not ready yet)"
echo
echo "== Installed Helm releases"
helm list -A --short 2>/dev/null
