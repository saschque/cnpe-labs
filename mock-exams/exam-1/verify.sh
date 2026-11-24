#!/usr/bin/env bash
# Scoring for mock exam 1
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { is 3 "$(jp -n mx-team-red get quota red-quota -o jsonpath='{.spec.hard.requests\.cpu}')" &&
        is 250m "$(jp -n mx-team-red get limitrange red-defaults -o jsonpath='{.spec.limits[0].default.cpu}')"; }
t2()  { is 12 "$(jp -n mx-team-red get hpa api -o jsonpath='{.spec.maxReplicas}')" &&
        is 2 "$(k -n mx-team-red get hpa api -o json | jq '.spec.metrics|length')"; }
t3()  { k -n mx-team-red get netpol -o json |
        jq -e '[.items[] | select(.spec.podSelector.matchLabels.app=="db") | .spec.ingress[0].ports[0].port==5432] | any'; }
t4()  { is Synced "$(jp -n argocd get app mx-kustomize -o jsonpath='{.status.sync.status}')" &&
        k -n mx-gb get deploy -o name | grep -q '/mx-'; }
t5()  { is Synced/Healthy "$(jp -n argocd get app mx-broken -o jsonpath='{.status.sync.status}/{.status.health.status}')"; }
t6()  { is 3 "$(jp -n mx-flux get deploy -o jsonpath='{.items[0].status.readyReplicas}')"; }
t7()  { k -n argo get wf -o json |
        jq -e '[.items[] | select(.spec.workflowTemplateRef.name=="mx-pipeline" and .status.phase=="Succeeded")] | length > 0'; }
t8()  { k -n ci get pipelinerun -o json |
        jq -e '[.items[] | select(.spec.pipelineRef.name=="mx-greet" and .status.conditions[0].reason=="Succeeded")] | length > 0'; }
t9()  { is 500 "$(jp -n mx-team-red get q orders -o jsonpath='{.spec.maxMessages}')"; }
t10() { is 50 "$(jp -n mx-team-red get cm logs -o jsonpath='{.data.size}')"; }
t11() { local ns="mx-verify-$$" r
        k create ns "$ns" >/dev/null && k label ns "$ns" mx-tenant=true >/dev/null; sleep 6
        k -n "$ns" get cm platform-info >/dev/null; r=$?
        k delete ns "$ns" --wait=false >/dev/null; return $r; }
t12() { k -n monitoring get prometheusrule mx-rules -o yaml | grep -q DeploymentReplicasMismatch; }
t13() { is 2 "$(jp -n mx-incident get deploy checkout -o jsonpath='{.status.readyReplicas}')" &&
        [[ -n $(jp -n mx-incident get endpoints checkout -o jsonpath='{.subsets[0].addresses[0].ip}') ]] &&
        [[ $(grep -c . /tmp/mx-incident.txt) -ge 2 ]]; }
t14() { grep -q 'topk(3' /tmp/mx-query.txt; }
t15() { local sa=system:serviceaccount:mx-team-red:mx-auditor
        is yes "$(k auth can-i list pods -A --as=$sa)" && is no "$(k auth can-i list secrets -A --as=$sa)"; }
t16() { ! k -n mx-team-red run nolimit --image=nginx:1.27 --dry-run=server >/dev/null; }
t17() { is restricted "$(jp get ns mx-team-red -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" &&
        k -n mx-team-red rollout status deploy api --timeout=10s >/dev/null; }

run_exam "4:Quota + LimitRange" "4:HPA 3-12, CPU+memory" "5:NetworkPolicy db <- api:5432" \
  "6:Argo CD mx-kustomize with namePrefix" "6:mx-broken fixed" "6:Flux HelmRelease mx-podinfo" \
  "6:Argo workflow mx-pipeline" "7:Tekton mx-greet" "7:CRD Queue + orders" "9:Crossplane Bucket -> ConfigMap" \
  "6:Kyverno generate platform-info" "6:PrometheusRule mx-rules" "7:Incident checkout" \
  "4:PromQL topk(3, ...)" "5:RBAC mx-auditor" "6:Kyverno mx-require-limits" "6:PSA restricted + api running"
