#!/usr/bin/env bash
# Punktebasierte Auswertung des Mock Exams
SCORE=0; MAX=0
k() { kubectl "$@" 2>/dev/null; }
jp() { k "$@"; }   # Kurzform für jsonpath-Abfragen

t1()  { [[ $(jp -n mx-team-red get quota red-quota -o jsonpath='{.spec.hard.requests\.cpu}') == 3 ]] &&
        [[ $(jp -n mx-team-red get limitrange red-defaults -o jsonpath='{.spec.limits[0].default.cpu}') == 250m ]]; }
t2()  { [[ $(jp -n mx-team-red get hpa api -o jsonpath='{.spec.maxReplicas}') == 12 ]] &&
        [[ $(k -n mx-team-red get hpa api -o json | jq '.spec.metrics|length') == 2 ]]; }
t3()  { k -n mx-team-red get netpol -o json |
        jq -e '[.items[] | select(.spec.podSelector.matchLabels.app=="db") | .spec.ingress[0].ports[0].port==5432] | any'; }
t4()  { [[ $(jp -n argocd get app mx-kustomize -o jsonpath='{.status.sync.status}') == Synced ]] &&
        k -n mx-gb get deploy -o name | grep -q '/mx-'; }
t5()  { [[ $(jp -n argocd get app mx-broken -o jsonpath='{.status.sync.status}/{.status.health.status}') == Synced/Healthy ]]; }
t6()  { [[ $(jp -n mx-flux get deploy -o jsonpath='{.items[0].status.readyReplicas}') == 3 ]]; }
t7()  { k -n argo get wf -o json |
        jq -e '[.items[] | select(.spec.workflowTemplateRef.name=="mx-pipeline" and .status.phase=="Succeeded")] | length > 0'; }
t8()  { k -n ci get pipelinerun -o json |
        jq -e '[.items[] | select(.spec.pipelineRef.name=="mx-greet" and .status.conditions[0].reason=="Succeeded")] | length > 0'; }
t9()  { [[ $(jp -n mx-team-red get q orders -o jsonpath='{.spec.maxMessages}') == 500 ]]; }
t10() { [[ $(jp -n mx-team-red get cm logs -o jsonpath='{.data.size}') == 50 ]]; }
t11() { local ns="mx-verify-$$" r
        k create ns "$ns" >/dev/null && k label ns "$ns" mx-tenant=true >/dev/null; sleep 6
        k -n "$ns" get cm platform-info >/dev/null; r=$?
        k delete ns "$ns" --wait=false >/dev/null; return $r; }
t12() { k -n monitoring get prometheusrule mx-rules -o yaml | grep -q DeploymentReplicasMismatch; }
t13() { [[ $(jp -n mx-incident get deploy checkout -o jsonpath='{.status.readyReplicas}') == 2 ]] &&
        [[ -n $(jp -n mx-incident get endpoints checkout -o jsonpath='{.subsets[0].addresses[0].ip}') ]] &&
        [[ $(wc -l < /tmp/mx-incident.txt) -ge 2 ]]; }
t14() { grep -q 'topk(3' /tmp/mx-query.txt; }
t15() { local sa=system:serviceaccount:mx-team-red:mx-auditor
        [[ $(k auth can-i list pods -A --as=$sa) == yes && $(k auth can-i list secrets -A --as=$sa) == no ]]; }
t16() { ! k -n mx-team-red run nolimit --image=nginx:1.27 --dry-run=server >/dev/null; }
t17() { [[ $(jp get ns mx-team-red -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}') == restricted ]] &&
        k -n mx-team-red rollout status deploy api --timeout=10s >/dev/null; }

POINTS=(0 4 4 5 6 6 6 6 7 7 9 6 6 7 4 5 6 6)
NAMES=("" "Quota + LimitRange" "HPA 3-12, CPU+Memory" "NetworkPolicy db <- api:5432"
  "Argo CD mx-kustomize mit namePrefix" "mx-broken repariert" "Flux HelmRelease mx-podinfo"
  "Argo Workflow mx-pipeline" "Tekton mx-greet" "CRD Queue + orders" "Crossplane Bucket -> ConfigMap"
  "Kyverno generate platform-info" "PrometheusRule mx-rules" "Incident checkout"
  "PromQL topk(3, ...)" "RBAC mx-auditor" "Kyverno mx-require-limits" "PSA restricted + api läuft")

for i in $(seq 1 17); do
  MAX=$((MAX + POINTS[i]))
  if "t$i" >/dev/null 2>&1; then
    SCORE=$((SCORE + POINTS[i])); printf "  ✅ %2d  %-40s +%d\n" "$i" "${NAMES[i]}" "${POINTS[i]}"
  else
    printf "  ❌ %2d  %-40s  0/%d\n" "$i" "${NAMES[i]}" "${POINTS[i]}"
  fi
done

PCT=$((SCORE * 100 / MAX))
echo
echo "Ergebnis: $SCORE / $MAX Punkte ($PCT %) – $([[ $PCT -ge 66 ]] && echo 'BESTANDEN 🎉' || echo 'noch nicht bestanden')"
