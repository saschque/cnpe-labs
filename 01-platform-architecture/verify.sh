#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
NS=team-payments
k() { kubectl "$@"; }

section "1.1 Mandanten-Namespace"
eq "Namespace-Label team=payments" "payments" k get ns $NS -o jsonpath='{.metadata.labels.team}'
eq "Quota requests.cpu=4" "4" k -n $NS get resourcequota payments-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "Quota LoadBalancer=0" "0" k -n $NS get resourcequota payments-quota -o jsonpath='{.spec.hard.services\.loadbalancers}'
eq "LimitRange defaultRequest cpu=100m" "100m" k -n $NS get limitrange payments-defaults -o jsonpath='{.spec.limits[0].defaultRequest.cpu}'
eq "LimitRange max memory=2Gi" "2Gi" k -n $NS get limitrange payments-defaults -o jsonpath='{.spec.limits[0].max.memory}'

section "1.2 HPA"
eq "HPA minReplicas=2" "2" k -n $NS get hpa checkout -o jsonpath='{.spec.minReplicas}'
eq "HPA maxReplicas=8" "8" k -n $NS get hpa checkout -o jsonpath='{.spec.maxReplicas}'
eq "HPA CPU 60%" "60" k -n $NS get hpa checkout -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}'
eq "Scale-Down-Fenster 120s" "120" k -n $NS get hpa checkout -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}'

section "1.3 Priority & PDB"
eq "PriorityClass Wert" "1000000" k get priorityclass platform-critical -o jsonpath='{.value}'
eq "Deployment nutzt PriorityClass" "platform-critical" k -n $NS get deploy checkout -o jsonpath='{.spec.template.spec.priorityClassName}'
eq "PDB minAvailable=1" "1" k -n $NS get pdb checkout-pdb -o jsonpath='{.spec.minAvailable}'
eq "TopologySpread maxSkew=1" "1" k -n $NS get deploy checkout -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}'

section "1.4 NetworkPolicies"
for np in default-deny allow-dns allow-from-frontend allow-same-namespace; do
  check "NetworkPolicy $np existiert" k -n $NS get networkpolicy $np
done
eq "default-deny blockiert Ingress+Egress" "Ingress Egress" k -n $NS get networkpolicy default-deny -o jsonpath='{.spec.policyTypes[*]}'

section "1.5 Storage"
eq "StorageClass Retain" "Retain" k get sc fast-retain -o jsonpath='{.reclaimPolicy}'
eq "StorageClass WaitForFirstConsumer" "WaitForFirstConsumer" k get sc fast-retain -o jsonpath='{.volumeBindingMode}'
eq "PVC ledger-data Bound" "Bound" k -n $NS get pvc ledger-data -o jsonpath='{.status.phase}'

section "1.6 OpenCost"
check "/tmp/cost-by-namespace.json ist gültiges JSON" jq -e .data /tmp/cost-by-namespace.json
check "/tmp/top-namespace.txt nicht leer" test -s /tmp/top-namespace.txt

section "1.7 Right-Sizing"
eq "Replicas=2" "2" k -n rightsizing get deploy oversized -o jsonpath='{.spec.replicas}'
eq "Kein CPU-Limit" "" k -n rightsizing get deploy oversized -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}'

section "1.8 Kustomize-Mandanten"
eq "team-a Quota cpu=2" "2" k -n team-a get resourcequota tenant-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "team-b Quota cpu=6" "6" k -n team-b get resourcequota tenant-quota -o jsonpath='{.spec.hard.requests\.cpu}'
eq "team-a-devs dürfen in team-a deployen" "yes" k auth can-i create deploy -n team-a --as=x --as-group=team-a-devs

summary
