#!/usr/bin/env bash
# Scoring for mock exam 4
source "$(dirname "$0")/../../setup/exam-lib.sh"

t1()  { jq -e .data /tmp/m4-cost.json >/dev/null && grep -q blue /tmp/m4-top-team.txt; }
t2()  { is 0 "$(jp -n m4-blue get quota m4-objects -o jsonpath='{.spec.hard.services\.nodeports}')" &&
        is 20 "$(jp -n m4-blue get quota m4-objects -o jsonpath='{.spec.hard.configmaps}')" &&
        is 5Gi "$(jp -n m4-blue get limitrange m4-pvc -o jsonpath='{.spec.limits[?(@.type=="PersistentVolumeClaim")].max.storage}')"; }
t3()  { is kubernetes.io/hostname "$(jp -n m4-blue get deploy api -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}')" &&
        [[ $(k -n m4-blue get pods -l app=api --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l) -eq 2 ]]; }
t4()  { is Synced "$(jp -n argocd get app m4-root -o jsonpath='{.status.sync.status}')" &&
        is apps "$(jp -n argocd get app m4-root -o jsonpath='{.spec.source.path}')" &&
        [[ $(k -n argocd get applications --no-headers | wc -l) -ge 3 ]]; }
t5()  { is m4-podinfo-values "$(jp -n m4-flux get helmrelease m4-podinfo -o jsonpath='{.spec.valuesFrom[0].name}')" &&
        is 2 "$(jp -n m4-flux get deploy -o jsonpath='{.items[0].status.readyReplicas}')"; }
t6()  { k -n ci get pipelinerun -o json | jq -e '[.items[] | select(.spec.pipelineRef.name=="m4-ci" and .status.conditions[0].reason=="Succeeded")] | length > 0'; }
t7()  { is false "$(jp -n argo get cronworkflow m4-report -o jsonpath='{.spec.suspend}')" &&
        is Europe/Berlin "$(jp -n argo get cronworkflow m4-report -o jsonpath='{.spec.timezone}')" &&
        k -n argo get cronworkflow m4-report -o jsonpath='{.spec.schedules}{.spec.schedule}' | grep -q '\*/30 \* \* \* \*' &&
        k -n argo get wf -o json | jq -e '[.items[] | select((.metadata.name | startswith("m4-report-")) and .status.phase=="Succeeded")] | length > 0'; }
t8()  { is bk "$(jp get crd backups.ops.m4.io -o jsonpath='{.spec.names.shortNames[0]}')" &&
        is 7 "$(jp -n m4-blue get backup nightly -o jsonpath='{.spec.retentionDays}')" &&
        ! k apply --dry-run=server -f - <<'EOF'
apiVersion: ops.m4.io/v1
kind: Backup
metadata: {name: verify-bad, namespace: m4-blue}
spec: {schedule: "x", retentionDays: 365, target: {kind: Tape, name: t}}
EOF
}
t9()  { is 14 "$(jp -n m4-blue get cm jobs -o jsonpath='{.data.retention}')"; }
t10() { is true "$(k apply --dry-run=server -o jsonpath='{.metadata.labels.platform\.m4\.io/managed}' -f - <<'EOF'
apiVersion: ops.m4.io/v1
kind: Backup
metadata: {name: verify-label, namespace: m4-blue}
spec: {schedule: "0 3 * * *", target: {kind: Volume, name: data}}
EOF
)"; }
t11() { k get crd widgets.legacy.m4.io >/dev/null && ! k -n m4-blue get widget stuck >/dev/null; }
t12() { is 1 "$(jp -n monitoring get cm m4-dashboard -o jsonpath='{.metadata.labels.grafana_dashboard}')" &&
        k -n monitoring get alertmanagerconfig m4-routing -o yaml | grep -q 'blue-hook.m4-blue:8080'; }
t13() { [[ $(grep -c . /tmp/m4-dora.txt) -ge 3 ]] && grep -q argocd_app_sync_total /tmp/m4-dora.txt &&
        grep -q argocd_app_info /tmp/m4-dora.txt; }
t14() { is nginx:1.27 "$(jp -n m4-incident get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}')" &&
        k -n m4-incident rollout status deploy web --timeout=10s >/dev/null &&
        is 5 "$(jp -n m4-incident get deploy web -o jsonpath='{.spec.revisionHistoryLimit}')" &&
        is web "$(jp -n m4-incident get hpa web -o jsonpath='{.spec.scaleTargetRef.name}')" &&
        [[ $(grep -c . /tmp/m4-incident.txt) -ge 2 ]]; }
t15() { local sa=system:serviceaccount:m4-ci:deployer
        is yes "$(k auth can-i patch deployments/web -n m4-incident --as=$sa)" &&
        is no "$(k auth can-i patch deployments/worker -n m4-incident --as=$sa)"; }
t16() { is restricted "$(jp get ns m4-secure -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" &&
        is Running "$(jp -n m4-secure get pod hardened -o jsonpath='{.status.phase}')"; }
t17() { grep -qx mallory /tmp/m4-audit.txt; }

run_exam "5:Cost per team" "5:Object quotas" "5:Anti-affinity" "6:App of apps" \
  "6:Flux valuesFrom" "7:Tekton fixed" "6:CronWorkflow" "7:CRD from spec" \
  "8:Crossplane troubleshooting" "5:Kyverno mutation" "5:Stuck object" "6:Dashboard + routing" \
  "6:DORA queries" "8:Broken rollout" "5:Least privilege" "5:PSA restricted" "5:Audit trail"
