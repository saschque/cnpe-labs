#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
TMPNS="verify-$$"

section "3.1 Database CRD"
check "CRD databases.platform.example.org exists" k get crd databases.platform.example.org
eq "Short Name db" "db" k get crd databases.platform.example.org -o jsonpath='{.spec.names.shortNames[0]}'
eq "Status subresource" "{}" k get crd databases.platform.example.org -o jsonpath='{.spec.versions[?(@.name=="v1alpha1")].subresources.status}'
check "engine=oracle is rejected" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: Database
metadata: {name: t1, namespace: default}
spec: {engine: oracle, version: '1'}
EOF"
check "storageGB=500 is rejected" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: Database
metadata: {name: t2, namespace: default}
spec: {engine: postgres, version: '16', storageGB: 500}
EOF"

section "3.2 CEL & versions"
check "HA with 10 GB is rejected" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: Database
metadata: {name: t3, namespace: default}
spec: {engine: postgres, version: '16', highAvailability: true}
EOF"
eq "v1beta1 served" "true" k get crd databases.platform.example.org -o jsonpath='{.spec.versions[?(@.name=="v1beta1")].served}'
eq "v1alpha1 deprecated" "true" k get crd databases.platform.example.org -o jsonpath='{.spec.versions[?(@.name=="v1alpha1")].deprecated}'

section "3.3 Crossplane WebApp"
eq "XRD Established" "True" k get xrd webapps.platform.example.org -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'
eq "WebApp shop Ready" "True" k -n team-a get webapp shop -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
eq "Deployment shop has 2 replicas" "2" k -n team-a get deploy shop -o jsonpath='{.spec.replicas}'
eq "status.url set" "http://shop.team-a.svc" k -n team-a get webapp shop -o jsonpath='{.status.url}'

section "3.4 Crossplane Troubleshooting"
eq "WebApp broken Ready" "True" k -n team-a get webapp broken -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

section "3.6 Kyverno generate"
if active; then   # creates a throwaway namespace – only when this section is selected
  k create ns "$TMPNS" >/dev/null 2>&1 && k label ns "$TMPNS" platform.example.org/tenant=true team=verify >/dev/null 2>&1
  sleep 8
fi
check "Quota generated" k -n "$TMPNS" get resourcequota tenant-quota
check "NetworkPolicy generated" k -n "$TMPNS" get networkpolicy default-deny
eq "RoleBinding for verify-devs" "verify-devs" k -n "$TMPNS" get rolebinding team-edit -o jsonpath='{.subjects[0].name}'
active && k delete ns "$TMPNS" --wait=false >/dev/null 2>&1

section "3.7 Self-service workflow"
check "WorkflowTemplate provision-tenant exists" k -n argo get workflowtemplate provision-tenant
check "At least one tenant-* namespace with WebApp welcome" bash -c \
  "kubectl get webapp -A --no-headers 2>/dev/null | grep -q '^tenant-.* welcome '"

section "3.8 RBAC"
eq "team-a-devs can create WebApps" "yes" k auth can-i create webapps.platform.example.org -n team-a --as=u --as-group=team-a-devs
eq "team-a-devs can NOT create Deployments" "no" k auth can-i create deployments -n team-a --as=u --as-group=team-a-devs
eq "team-a-devs can read Deployments" "yes" k auth can-i list deployments -n team-a --as=u --as-group=team-a-devs

section "3.9 / 3.10 Size profiles"
eq "Composition webapp-sized with label profile=sized" "sized" k get composition webapp-sized -o jsonpath='{.metadata.labels.profile}'
eq "catalog uses the selector" "sized" k -n team-a get webapp catalog -o jsonpath='{.spec.crossplane.compositionSelector.matchLabels.profile}'
eq "catalog: 2 replicas, 256Mi" "2 256Mi" k -n team-a get deploy catalog -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].resources.requests.memory}'
eq "status.availableReplicas=2" "2" k -n team-a get webapp catalog -o jsonpath='{.status.availableReplicas}'

section "3.11 Guardrails"
check "ClusterPolicy webapp-guardrails exists" k get clusterpolicy webapp-guardrails
check "WebApp with :latest is rejected" bash -c "! kubectl apply --dry-run=server -f - <<'EOT'
apiVersion: platform.example.org/v1alpha1
kind: WebApp
metadata: {name: latest-test, namespace: team-a}
spec: {image: 'nginx:latest'}
EOT"

section "3.12 Package lifecycle"
eq "revisionActivationPolicy=Manual" "Manual" k get function function-patch-and-transform -o jsonpath='{.spec.revisionActivationPolicy}'
check "At least 2 FunctionRevisions" bash -c "[[ \$(kubectl get functionrevisions --no-headers | grep -c patch-and-transform) -ge 2 ]]"

summary
