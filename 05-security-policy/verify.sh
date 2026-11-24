#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
SA=system:serviceaccount:ci:deployer

section "5.1 / 5.2 Istio"
eq "PeerAuthentication STRICT" "STRICT" k -n shop get peerauthentication default -o jsonpath='{.spec.mtls.mode}'
check "AuthorizationPolicy deny-all" k -n shop get authorizationpolicy deny-all
eq "shop/sleep GET /get → 200" "200" k -n shop exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' http://httpbin.shop/get
eq "shop/sleep POST /post → 403" "403" k -n shop exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' -X POST http://httpbin.shop/post
check "legacy/sleep wird abgewiesen" bash -c "! kubectl -n legacy exec deploy/sleep -- curl -sf -m 5 http://httpbin.shop/get"

section "5.4 RBAC"
eq "deployer darf in gb-dev patchen" "yes" k auth can-i patch deploy -n gb-dev --as=$SA
eq "deployer darf NICHT löschen" "no" k auth can-i delete deploy -n gb-dev --as=$SA
eq "deployer darf NICHT in gb-prod" "no" k auth can-i patch deploy -n gb-prod --as=$SA
eq "deployer darf Namespaces listen" "yes" k auth can-i list ns --as=$SA
eq "Token-Automount aus" "false" k -n ci get sa deployer -o jsonpath='{.automountServiceAccountToken}'

section "5.5 PSA"
eq "secure-apps enforce=baseline" "baseline" k get ns secure-apps -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
check "Privilegierter Pod wird abgelehnt" bash -c "! kubectl -n secure-apps run priv-test --dry-run=server --image=nginx --overrides='{\"spec\":{\"containers\":[{\"name\":\"p\",\"image\":\"nginx\",\"securityContext\":{\"privileged\":true}}]}}'"

section "5.6 Kyverno"
for p in require-team-label disallow-latest-tag add-default-resources require-probes; do
  check "ClusterPolicy $p existiert" k get clusterpolicy $p
done
check "Deployment ohne team-Label wird abgelehnt" bash -c "! kubectl -n default create deploy kv-test --image=nginx:1.27 --dry-run=server"
check "Image :latest wird abgelehnt" bash -c "! kubectl -n default run kv-latest --image=nginx:latest --dry-run=server"

section "5.7 Gatekeeper"
check "ConstraintTemplate k8srequiredlabels" k get constrainttemplate k8srequiredlabels
eq "Constraint auf deny" "deny" k get k8srequiredlabels ns-must-have-owner -o jsonpath='{.spec.enforcementAction}'
check "Namespace ohne owner wird abgelehnt" bash -c "! kubectl create ns gk-test-no-owner --dry-run=server"

section "5.9 Secure Pipeline"
for t in trivy-scan sbom kyverno-test; do
  check "Task $t existiert" k -n ci get task $t
done
check "Pipeline secure-pipeline existiert" k -n ci get pipeline secure-pipeline

summary
