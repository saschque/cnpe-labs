#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
NS=team-payments
k() { kubectl "$@"; }

section "1.1 Tenant namespace"
eq "Namespace-Label team=payments" "payments" k get ns $NS -o jsonpath='{.metadata.labels.team}'
eq "Quota requests.cpu=4" "4" k -n $NS get resourcequota payments-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "Quota LoadBalancer=0" "0" k -n $NS get resourcequota payments-quota -o jsonpath='{.spec.hard.services\.loadbalancers}'
eq "LimitRange defaultRequest cpu=100m" "100m" k -n $NS get limitrange payments-defaults -o jsonpath='{.spec.limits[0].defaultRequest.cpu}'
eq "LimitRange max memory=2Gi" "2Gi" k -n $NS get limitrange payments-defaults -o jsonpath='{.spec.limits[0].max.memory}'

section "1.2 HPA"
eq "HPA minReplicas=2" "2" k -n $NS get hpa checkout -o jsonpath='{.spec.minReplicas}'
eq "HPA maxReplicas=8" "8" k -n $NS get hpa checkout -o jsonpath='{.spec.maxReplicas}'
eq "HPA CPU 60%" "60" k -n $NS get hpa checkout -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}'
eq "Scale-down window 120s" "120" k -n $NS get hpa checkout -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}'

section "1.3 Priority & PDB"
eq "PriorityClass value" "1000000" k get priorityclass platform-critical -o jsonpath='{.value}'
eq "Deployment uses PriorityClass" "platform-critical" k -n $NS get deploy checkout -o jsonpath='{.spec.template.spec.priorityClassName}'
eq "PDB minAvailable=1" "1" k -n $NS get pdb checkout-pdb -o jsonpath='{.spec.minAvailable}'
eq "TopologySpread maxSkew=1" "1" k -n $NS get deploy checkout -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}'

section "1.4 NetworkPolicies"
for np in default-deny allow-dns allow-from-frontend allow-same-namespace; do
  check "NetworkPolicy $np exists" k -n $NS get networkpolicy $np
done
eq "default-deny blocks Ingress+Egress" "Ingress Egress" k -n $NS get networkpolicy default-deny -o jsonpath='{.spec.policyTypes[*]}'

section "1.5 Storage"
eq "StorageClass Retain" "Retain" k get sc fast-retain -o jsonpath='{.reclaimPolicy}'
eq "StorageClass WaitForFirstConsumer" "WaitForFirstConsumer" k get sc fast-retain -o jsonpath='{.volumeBindingMode}'
eq "PVC ledger-data Bound" "Bound" k -n $NS get pvc ledger-data -o jsonpath='{.status.phase}'

section "1.6 OpenCost"
check "/tmp/cost-by-namespace.json is valid JSON" jq -e .data /tmp/cost-by-namespace.json
check "/tmp/top-namespace.txt not empty" test -s /tmp/top-namespace.txt

section "1.7 Right-Sizing"
eq "Replicas=2" "2" k -n rightsizing get deploy oversized -o jsonpath='{.spec.replicas}'
eq "No CPU limit" "" k -n rightsizing get deploy oversized -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}'

section "1.8 Kustomize tenants"
eq "team-a Quota cpu=2" "2" k -n team-a get resourcequota tenant-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "team-b Quota cpu=6" "6" k -n team-b get resourcequota tenant-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "team-a-devs can deploy in team-a" "yes" k auth can-i create deploy -n team-a --as=x --as-group=team-a-devs

section "1.9 Dedicated node pool"
eq "Node cnpe-worker2 has pool=platform" "platform" k get node cnpe-worker2 -o jsonpath='{.metadata.labels.pool}'
check "All platform-agent pods on cnpe-worker2" bash -c \
  "[[ \$(kubectl -n platform-system get pods -l app=platform-agent -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\\n' | sort -u) == cnpe-worker2 ]]"
eq "Toleration set" "dedicated" k -n platform-system get deploy platform-agent -o jsonpath='{.spec.template.spec.tolerations[0].key}'

section "1.10 StatefulSet"
eq "Headless Service" "None" k -n data get svc kv -o jsonpath='{.spec.clusterIP}'
eq "serviceName=kv" "kv" k -n data get sts kv -o jsonpath='{.spec.serviceName}'
check "PVC data-kv-0 Bound" bash -c "[[ \$(kubectl -n data get pvc data-kv-0 -o jsonpath='{.status.phase}') == Bound ]]"

section "1.11 Scoped Quotas"
eq "critical-quota scoped to platform-critical" "platform-critical" k -n $NS get quota critical-quota -o jsonpath='{.spec.scopeSelector.matchExpressions[0].values[0]}'
eq "no-besteffort Scope" "BestEffort" k -n $NS get quota no-besteffort -o jsonpath='{.spec.scopes[0]}'

section "1.12 Capacity analysis"
check "/tmp/node-requests.txt: one line per node" bash -c \
  "[[ \$(grep -c . /tmp/node-requests.txt) -eq \$(kubectl get nodes --no-headers | wc -l) ]]"
check "/tmp/top-requests-ns.txt names an existing namespace" bash -c "kubectl get ns \$(cat /tmp/top-requests-ns.txt)"

summary
