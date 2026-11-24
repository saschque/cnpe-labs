#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }

section "4.1 ServiceMonitor"
check "ServiceMonitor podinfo exists" k -n demo get servicemonitor podinfo
eq "Interval 15s" "15s" k -n demo get servicemonitor podinfo -o jsonpath='{.spec.endpoints[0].interval}'

section "4.2 PromQL"
check "/tmp/promql.txt has ≥ 6 lines" bash -c '[[ $(grep -cv "^\s*$" /tmp/promql.txt) -ge 6 ]]'

section "4.3 PrometheusRule"
check "PrometheusRule platform-alerts exists" k -n monitoring get prometheusrule platform-alerts
eq "Alert PodCrashLooping critical" "critical" k -n monitoring get prometheusrule platform-alerts \
  -o jsonpath='{.spec.groups[*].rules[?(@.alert=="PodCrashLooping")].labels.severity}'
check "Recording rule present" bash -c "kubectl -n monitoring get prometheusrule platform-alerts -o yaml | grep -q 'record: namespace:container_cpu_usage:sum_rate5m'"

section "4.4 Dashboard"
eq "ConfigMap with grafana_dashboard=1" "1" k -n monitoring get cm podinfo-dashboard -o jsonpath='{.metadata.labels.grafana_dashboard}'

section "4.5 OTel"
eq "otel-collector available" "1" k -n observability get deploy otel-collector -o jsonpath='{.status.availableReplicas}'
check "podinfo exports to the collector" bash -c "kubectl -n demo get deploy podinfo -o yaml | grep -q otel-collector.observability"

section "4.7 Incidents"
for d in s1-web s2-api s3-worker s4-batch s6-cache s7-report; do
  eq "$d fully available" "$(k -n incidents get deploy $d -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    k -n incidents get deploy $d -o jsonpath='{.status.readyReplicas}'
done
check "s5-frontend has endpoints" bash -c "kubectl -n incidents get endpoints s5-frontend -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -q ."
check "s5-frontend answers on port 80" kubectl -n default run curl-verify --rm -i --restart=Never --image=curlimages/curl -- curl -sf -m 5 http://s5-frontend.incidents

section "4.8 PodMonitor"
check "PodMonitor podinfo-pods exists" k -n demo get podmonitor podinfo-pods
eq "Container port is named http-metrics" "http-metrics" k -n demo get deploy podinfo -o jsonpath='{.spec.template.spec.containers[0].ports[0].name}'

section "4.9 Logs"
check "/tmp/error-count.txt is a number > 0" bash -c '[[ $(cat /tmp/error-count.txt) =~ ^[0-9]+$ && $(cat /tmp/error-count.txt) -gt 0 ]]'
check "/tmp/noisy-pod.txt names a chatty pod" bash -c "kubectl -n logs-demo get pod \$(cat /tmp/noisy-pod.txt)"

section "4.10 SLO"
check "Recording rule ratio_rate1h" bash -c "kubectl -n monitoring get prometheusrule podinfo-slo -o yaml | grep -q 'sli:podinfo_errors:ratio_rate1h'"
eq "Fast-burn alert critical" "critical" k -n monitoring get prometheusrule podinfo-slo \
  -o jsonpath='{.spec.groups[*].rules[?(@.alert=="PodinfoErrorBudgetBurnFast")].labels.severity}'

section "4.11 Spanmetrics"
check "Connector spanmetrics configured" bash -c "kubectl -n observability get cm otel-collector-config -o jsonpath='{.data.config\\.yaml}' | grep -q spanmetrics"
check "Service port 8889" bash -c "kubectl -n observability get svc otel-collector -o jsonpath='{.spec.ports[*].port}' | grep -qw 8889"
check "ServiceMonitor otel-collector" k -n observability get servicemonitor otel-collector

section "4.12 Incidents round 2"
for d in s8-billing s9-search s10-uploads s11-sync s12-resolver; do
  eq "$d ready" "1" k -n incidents-2 get deploy $d -o jsonpath='{.status.readyReplicas}'
done
check "s9-search without new restarts (≤ 5)" bash -c \
  "[[ \$(kubectl -n incidents-2 get pods -l app=s9-search -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}') -le 5 ]]"
check "lockdown-egress not deleted" k -n incidents-2 get networkpolicy lockdown-egress

summary
