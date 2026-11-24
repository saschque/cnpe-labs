#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
SA=system:serviceaccount:ci:deployer

section "5.1 / 5.2 Istio"
eq "PeerAuthentication STRICT" "STRICT" k -n shop get peerauthentication default -o jsonpath='{.spec.mtls.mode}'
check "AuthorizationPolicy deny-all" k -n shop get authorizationpolicy deny-all
eq "shop/sleep GET /get → 200" "200" k -n shop exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' http://httpbin.shop/get
eq "shop/sleep POST /post → 403" "403" k -n shop exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' -X POST http://httpbin.shop/post
check "legacy/sleep is rejected" bash -c "! kubectl -n legacy exec deploy/sleep -- curl -sf -m 5 http://httpbin.shop/get"

section "5.4 RBAC"
eq "deployer can patch in gb-dev" "yes" k auth can-i patch deploy -n gb-dev --as=$SA
eq "deployer can NOT delete" "no" k auth can-i delete deploy -n gb-dev --as=$SA
eq "deployer can NOT act in gb-prod" "no" k auth can-i patch deploy -n gb-prod --as=$SA
eq "deployer can list namespaces" "yes" k auth can-i list ns --as=$SA
eq "Token automount disabled" "false" k -n ci get sa deployer -o jsonpath='{.automountServiceAccountToken}'

section "5.5 PSA"
eq "secure-apps enforce=baseline" "baseline" k get ns secure-apps -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
check "Privileged pod is rejected" bash -c "! kubectl -n secure-apps run priv-test --dry-run=server --image=nginx --overrides='{\"spec\":{\"containers\":[{\"name\":\"p\",\"image\":\"nginx\",\"securityContext\":{\"privileged\":true}}]}}'"

section "5.6 Kyverno"
for p in require-team-label disallow-latest-tag add-default-resources require-probes; do
  check "ClusterPolicy $p exists" k get clusterpolicy $p
done
check "Deployment without team label is rejected" bash -c "! kubectl -n default create deploy kv-test --image=nginx:1.27 --dry-run=server"
check "Image :latest is rejected" bash -c "! kubectl -n default run kv-latest --image=nginx:latest --dry-run=server"

section "5.7 Gatekeeper"
check "ConstraintTemplate k8srequiredlabels" k get constrainttemplate k8srequiredlabels
eq "Constraint set to deny" "deny" k get k8srequiredlabels ns-must-have-owner -o jsonpath='{.spec.enforcementAction}'
check "Namespace without owner is rejected" bash -c "! kubectl create ns gk-test-no-owner --dry-run=server"

section "5.9 Secure pipeline"
for t in trivy-scan sbom kyverno-test; do
  check "Task $t exists" k -n ci get task $t
done
check "Pipeline secure-pipeline exists" k -n ci get pipeline secure-pipeline

section "5.10 Istio egress"
eq "Sidecar REGISTRY_ONLY" "REGISTRY_ONLY" k -n shop get sidecar default -o jsonpath='{.spec.outboundTrafficPolicy.mode}'
check "ServiceEntry httpbin-org" k -n shop get serviceentry httpbin-org
eq "example.com blocked (502)" "502" k -n shop exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' -m 10 http://example.com

section "5.11 Kyverno PSS"
check "ClusterPolicy pss-restricted" k get clusterpolicy pss-restricted
check "nginx pod in strict-apps rejected" bash -c "! kubectl -n strict-apps run pss-test --image=nginx:1.27 --dry-run=server"

section "5.12 Gatekeeper mutation"
check "Assign always-pull" k get assign always-pull
check "Mutation sets label owner=platform" bash -c \
  "kubectl -n shop run mut-verify --image=nginx:1.27 --dry-run=server -o jsonpath='{.metadata.labels.owner}' | grep -q platform"

section "5.13 RBAC audit"
check "/tmp/cluster-admins.txt contains legacy-bot" grep -q legacy-bot /tmp/cluster-admins.txt
check "/tmp/secret-readers.txt contains debugger" grep -q debugger /tmp/secret-readers.txt
eq "legacy-bot can no longer read secrets" "no" k auth can-i list secrets -A --as=system:serviceaccount:ci:legacy-bot
eq "legacy-bot has view in ci" "yes" k auth can-i list pods -n ci --as=system:serviceaccount:ci:legacy-bot

summary
