#!/usr/bin/env bash
# Scoring for mock exam 2
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { local nodes; nodes=$(jp -n m2-batch get pods -l app=cruncher --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}')
        [[ -n $nodes ]] && [[ $(tr ' ' '\n' <<<"$nodes" | sort -u) == cnpe-worker ]] &&
        is 2 "$(jp -n m2-batch get deploy cruncher -o jsonpath='{.status.readyReplicas}')"; }
t2()  { is 100000 "$(jp get priorityclass m2-high -o jsonpath='{.value}')" &&
        is m2-high "$(jp -n m2-shop get deploy web -o jsonpath='{.spec.template.spec.priorityClassName}')" &&
        is 1 "$(jp -n m2-shop get pdb web-pdb -o jsonpath='{.spec.maxUnavailable}')"; }
t3()  { is 2 "$(jp -n m2-shop get limitrange m2-ratio -o jsonpath='{.spec.limits[0].maxLimitRequestRatio.memory}')" &&
        is BestEffort "$(jp -n m2-shop get quota m2-no-besteffort -o jsonpath='{.spec.scopes[0]}')"; }
t4()  { is Synced "$(jp -n argocd get app m2-helm-guestbook -o jsonpath='{.status.sync.status}')" &&
        is Synced "$(jp -n argocd get app m2-kustomize-guestbook -o jsonpath='{.status.sync.status}')"; }
t5()  { is m2-team "$(jp -n argocd get app m2-gb -o jsonpath='{.spec.project}')" &&
        is Synced/Healthy "$(jp -n argocd get app m2-gb -o jsonpath='{.status.sync.status}/{.status.health.status}')" &&
        is 'm2-team-*' "$(jp -n argocd get appproject m2-team -o jsonpath='{.spec.destinations[0].namespace}')"; }
t6()  { is 3 "$(jp -n m2-flux get hpa podinfo -o jsonpath='{.spec.minReplicas}')"; }
t7()  { k -n ci get pipelinerun -o json | jq -e '[.items[] | select(.spec.pipelineRef.name=="m2-release"
          and .status.conditions[0].reason=="Succeeded" and ([.status.skippedTasks[]?.name] | index("test") != null))] | length > 0'; }
t8()  { k -n argo get wf -o json | jq -e '[.items[] | select(.spec.workflowTemplateRef.name=="m2-fanout" and .status.phase=="Succeeded")] | length > 0'; }
t9()  { is Cluster "$(jp get crd environments.platform.m2.io -o jsonpath='{.spec.scope}')" &&
        is cto "$(jp get environment checkout-prod -o jsonpath='{.spec.approvedBy}')" &&
        ! k apply --dry-run=server -f - <<'EOF'
apiVersion: platform.m2.io/v1
kind: Environment
metadata: {name: verify-no-approval}
spec: {tier: prod, owner: x}
EOF
}
t10() { is 1Gi "$(jp -n m2-shop get cm sessions -o jsonpath='{.data.memory}')" &&
        is redis "$(jp -n m2-shop get cm sessions -o jsonpath='{.data.engine}')"; }
t11() { is yes "$(k auth can-i create caches.cache.m2.io -n m2-shop --as=u --as-group=m2-devs)" &&
        is no "$(k auth can-i create configmaps -n m2-shop --as=u --as-group=m2-devs)" &&
        is yes "$(k auth can-i list configmaps -n m2-shop --as=u --as-group=m2-devs)"; }
t12() { ! k apply --dry-run=server -f - <<'EOF'
apiVersion: cache.m2.io/v1alpha1
kind: Cache
metadata: {name: verify-large, namespace: m2-dev}
spec: {size: large}
EOF
}
t13() { is 2 "$(jp -n m2-incident get deploy api -o jsonpath='{.status.readyReplicas}')" &&
        [[ $(k -n m2-incident get pods -l app=api -o json | jq '[.items[].status.containerStatuses[0].restartCount] | max') -le 1 ]]; }
t14() { k -n monitoring get prometheusrule m2-slo -o yaml | grep -q 'sli:m2_api_errors:ratio_rate1h' &&
        is critical "$(jp -n monitoring get prometheusrule m2-slo -o jsonpath='{.spec.groups[*].rules[?(@.alert=="M2ErrorBudgetBurn")].labels.severity}')"; }
t15() { is 1 "$(jp -n m2-otel get deploy otel-collector -o jsonpath='{.status.availableReplicas}')" &&
        is 4317 "$(jp -n m2-otel get svc otel-collector -o jsonpath='{.spec.ports[?(@.name=="otlp-grpc")].targetPort}')" &&
        k -n m2-otel get cm otel-collector-config -o jsonpath='{.data.config\.yaml}' | grep -q 'jaeger.observability:4317'; }
t16() { k get clusterpolicy m2-restricted >/dev/null &&
        k -n m2-secure rollout status deploy app --timeout=10s >/dev/null &&
        ! k -n m2-secure run verify-root --image=nginx:1.27 --dry-run=server >/dev/null; }
t17() { grep -q 'm2-shop/old-ci' /tmp/m2-admins.txt && grep -q 'm2-batch/backup-agent' /tmp/m2-admins.txt &&
        is no "$(k auth can-i list secrets -A --as=system:serviceaccount:m2-shop:old-ci)" &&
        is yes "$(k auth can-i create deployments -n m2-shop --as=system:serviceaccount:m2-shop:old-ci)"; }

run_exam "5:Batch pool" "5:PriorityClass + PDB" "5:LimitRange ratio + quota" "5:ApplicationSet Git dirs" \
  "5:AppProject + Application" "5:Flux with HPA patch" "5:Tekton when/finally" "5:Argo fan-out" \
  "7:CRD with CEL" "9:Crossplane map transform" "4:RBAC platform API" "5:Kyverno guardrail" \
  "7:Incident api" "6:SLO alert" "7:OTel Collector fixed" "8:Kyverno podSecurity + fix" "7:RBAC audit"
