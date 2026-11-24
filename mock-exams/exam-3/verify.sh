#!/usr/bin/env bash
# Scoring for mock exam 3
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { k -n m3-app get netpol web-egress -o json | jq -e '
          (.spec.policyTypes | index("Egress")) != null and
          ([.spec.egress[].ports[]?.port] | index(5432) != null) and
          ([.spec.egress[].ports[]?.port] | index(53) != null)'; }
t2()  { is None "$(jp -n m3-db get svc cache -o jsonpath='{.spec.clusterIP}')" &&
        is 2 "$(jp -n m3-db get sts cache -o jsonpath='{.status.readyReplicas}')" &&
        is Bound "$(jp -n m3-db get pvc data-cache-1 -o jsonpath='{.status.phase}')"; }
t3()  { is 6 "$(jp -n m3-app get hpa web -o jsonpath='{.spec.maxReplicas}')" &&
        is 2 "$(jp -n m3-app get hpa web -o jsonpath='{.spec.behavior.scaleUp.policies[0].value}')" &&
        is 300 "$(jp -n m3-app get hpa web -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}')"; }
t4()  { is /spec/replicas "$(jp -n argocd get app m3-guestbook -o jsonpath='{.spec.ignoreDifferences[0].jsonPointers[0]}')" &&
        k -n argocd get app m3-guestbook -o jsonpath='{.spec.syncPolicy.syncOptions}' | grep -q RespectIgnoreDifferences=true &&
        is Synced "$(jp -n argocd get app m3-guestbook -o jsonpath='{.status.sync.status}')"; }
t5()  { is True "$(jp -n flux-system get kustomization m3-podinfo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" &&
        k -n m3-flux get deploy podinfo >/dev/null; }
t6()  { k -n ci get pipelinerun -o json | jq -e '[.items[] | select(.spec.pipelineRef.name=="m3-build")
          | .status.results[]? | select(.name=="tag" and .value=="v1.0.42")] | length > 0'; }
t7()  { is notify "$(jp -n argo get workflowtemplate m3-deploy -o jsonpath='{.spec.onExit}')" &&
        k -n argo get wf -o json | jq -e '[.items[] | select(.spec.workflowTemplateRef.name=="m3-deploy" and .status.phase=="Succeeded")] | length > 0'; }
t8()  { is 30 "$(jp -n m3-canary get canary podinfo -o jsonpath='{.spec.analysis.maxWeight}')" &&
        k -n m3-canary get deploy podinfo-primary >/dev/null &&
        [[ $(jp -n m3-canary get canary podinfo -o jsonpath='{.status.phase}') =~ ^(Initialized|Succeeded)$ ]]; }
t9()  { is true "$(jp get crd tenants.platform.m3.io -o jsonpath='{.spec.versions[?(@.name=="v1alpha1")].deprecated}')" &&
        is true "$(jp get crd tenants.platform.m3.io -o jsonpath='{.spec.versions[?(@.name=="v1")].storage}')" &&
        is Active "$(jp get tenant red -o jsonpath='{.status.phase}')"; }
t10() { is True "$(jp -n m3-app get webservice shop -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" &&
        is 2 "$(jp -n m3-app get webservice shop -o jsonpath='{.status.readyReplicas}')" &&
        k -n m3-app get svc shop >/dev/null; }
t11() { local ns="m3-verify-$$" r
        k create ns "$ns" >/dev/null && k label ns "$ns" m3-tenant=true >/dev/null; sleep 6
        k -n "$ns" get netpol default-deny-ingress >/dev/null && k -n "$ns" get limitrange defaults >/dev/null; r=$?
        k delete ns "$ns" --wait=false >/dev/null; return $r; }
t12() { k -n m3-app get webservice orders >/dev/null &&
        k -n argo get wf -o json | jq -e '[.items[] | select(.spec.workflowTemplateRef.name=="m3-new-service" and .status.phase=="Succeeded")] | length > 0'; }
t13() { is podinfo "$(jp -n m3-mon get servicemonitor podinfo -o jsonpath='{.spec.selector.matchLabels.app}')" &&
        is web "$(jp -n m3-mon get servicemonitor podinfo -o jsonpath='{.spec.endpoints[0].port}')" &&
        is podinfo "$(jp -n m3-mon get svc podinfo -o jsonpath='{.metadata.name}')"; }
t14() { k -n monitoring get prometheusrule m3-rules -o yaml | grep -q M3NodeMemoryHigh &&
        grep -q 'topk(3' /tmp/m3-query.txt && grep -q m3-app /tmp/m3-query.txt; }
t15() { is 1 "$(jp -n m3-incident get deploy worker -o jsonpath='{.status.readyReplicas}')" &&
        is 1 "$(jp -n m3-incident get deploy frontend -o jsonpath='{.status.readyReplicas}')" &&
        k -n m3-incident get netpol deny-all-egress >/dev/null &&
        [[ $(grep -c . /tmp/m3-incident.txt) -ge 2 ]]; }
t16() { is STRICT "$(jp -n m3-mesh get peerauthentication default -o jsonpath='{.spec.mtls.mode}')" &&
        is 200 "$(k -n m3-mesh exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' http://httpbin.m3-mesh/get)" &&
        is 403 "$(k -n m3-mesh exec deploy/sleep -c sleep -- curl -s -o /dev/null -w '%{http_code}' -X POST http://httpbin.m3-mesh/post)" &&
        ! k -n m3-outside exec deploy/sleep -- curl -sf -m 5 http://httpbin.m3-mesh/get >/dev/null; }
t17() { is deny "$(jp get k8sallowedrepos m3-registries -o jsonpath='{.spec.enforcementAction}')" &&
        ! k -n m3-restricted run verify-dockerhub --image=nginx:1.27 --dry-run=server >/dev/null &&
        k -n m3-restricted run verify-ok --image=registry.k8s.io/pause:3.10 --dry-run=server >/dev/null; }

run_exam "5:Egress NetworkPolicy" "5:StatefulSet" "5:HPA with behavior" "5:Argo CD ignoreDifferences" \
  "5:Flux fixed" "5:Tekton results" "5:Argo retry + exit handler" "5:Flagger Canary" \
  "6:CRD with two versions" "10:Crossplane API" "5:Kyverno generate" "4:Self-service workflow" \
  "6:ServiceMonitor fixed" "6:Alert + Query" "8:Incident" "8:Istio mTLS + AuthZ" "7:Gatekeeper registries"
