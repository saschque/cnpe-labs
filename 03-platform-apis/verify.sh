#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
TMPNS="verify-$$"

section "3.1 Database-CRD"
check "CRD databases.platform.example.org existiert" k get crd databases.platform.example.org
eq "Short Name db" "db" k get crd databases.platform.example.org -o jsonpath='{.spec.names.shortNames[0]}'
eq "Status-Subresource" "{}" k get crd databases.platform.example.org -o jsonpath='{.spec.versions[?(@.name=="v1alpha1")].subresources.status}'
check "engine=oracle wird abgelehnt" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: Database
metadata: {name: t1, namespace: default}
spec: {engine: oracle, version: '1'}
EOF"
check "storageGB=500 wird abgelehnt" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: Database
metadata: {name: t2, namespace: default}
spec: {engine: postgres, version: '16', storageGB: 500}
EOF"

section "3.2 CEL & Versionen"
check "HA mit 10 GB wird abgelehnt" bash -c "! kubectl apply --dry-run=server -f - <<'EOF'
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
eq "Deployment shop hat 2 Replicas" "2" k -n team-a get deploy shop -o jsonpath='{.spec.replicas}'
eq "status.url gesetzt" "http://shop.team-a.svc" k -n team-a get webapp shop -o jsonpath='{.status.url}'

section "3.4 Crossplane Troubleshooting"
eq "WebApp broken Ready" "True" k -n team-a get webapp broken -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

section "3.6 Kyverno generate"
k create ns "$TMPNS" >/dev/null 2>&1 && k label ns "$TMPNS" platform.example.org/tenant=true team=verify >/dev/null 2>&1
sleep 8
check "Quota generiert" k -n "$TMPNS" get resourcequota tenant-quota
check "NetworkPolicy generiert" k -n "$TMPNS" get networkpolicy default-deny
eq "RoleBinding für verify-devs" "verify-devs" k -n "$TMPNS" get rolebinding team-edit -o jsonpath='{.subjects[0].name}'
k delete ns "$TMPNS" --wait=false >/dev/null 2>&1

section "3.7 Self-Service-Workflow"
check "WorkflowTemplate provision-tenant existiert" k -n argo get workflowtemplate provision-tenant
check "Mind. ein tenant-*-Namespace mit WebApp welcome" bash -c \
  "kubectl get webapp -A --no-headers 2>/dev/null | grep -q '^tenant-.* welcome '"

section "3.8 RBAC"
eq "team-a-devs dürfen WebApps erstellen" "yes" k auth can-i create webapps.platform.example.org -n team-a --as=u --as-group=team-a-devs
eq "team-a-devs dürfen KEINE Deployments erstellen" "no" k auth can-i create deployments -n team-a --as=u --as-group=team-a-devs
eq "team-a-devs dürfen Deployments lesen" "yes" k auth can-i list deployments -n team-a --as=u --as-group=team-a-devs

summary
