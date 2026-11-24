#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }

section "4.1 ServiceMonitor"
check "ServiceMonitor podinfo existiert" k -n demo get servicemonitor podinfo
eq "Intervall 15s" "15s" k -n demo get servicemonitor podinfo -o jsonpath='{.spec.endpoints[0].interval}'

section "4.2 PromQL"
check "/tmp/promql.txt hat ≥ 6 Zeilen" bash -c '[[ $(grep -cv "^\s*$" /tmp/promql.txt) -ge 6 ]]'

section "4.3 PrometheusRule"
check "PrometheusRule platform-alerts existiert" k -n monitoring get prometheusrule platform-alerts
eq "Alert PodCrashLooping critical" "critical" k -n monitoring get prometheusrule platform-alerts \
  -o jsonpath='{.spec.groups[*].rules[?(@.alert=="PodCrashLooping")].labels.severity}'
check "Recording Rule vorhanden" bash -c "kubectl -n monitoring get prometheusrule platform-alerts -o yaml | grep -q 'record: namespace:container_cpu_usage:sum_rate5m'"

section "4.4 Dashboard"
eq "ConfigMap mit grafana_dashboard=1" "1" k -n monitoring get cm podinfo-dashboard -o jsonpath='{.metadata.labels.grafana_dashboard}'

section "4.5 OTel"
eq "otel-collector verfügbar" "1" k -n observability get deploy otel-collector -o jsonpath='{.status.availableReplicas}'
check "podinfo exportiert an Collector" bash -c "kubectl -n demo get deploy podinfo -o yaml | grep -q otel-collector.observability"

section "4.7 Incidents"
for d in s1-web s2-api s3-worker s4-batch s6-cache s7-report; do
  eq "$d vollständig verfügbar" "$(k -n incidents get deploy $d -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    k -n incidents get deploy $d -o jsonpath='{.status.readyReplicas}'
done
check "s5-frontend hat Endpoints" bash -c "kubectl -n incidents get endpoints s5-frontend -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -q ."
check "s5-frontend antwortet auf Port 80" kubectl -n default run curl-verify --rm -i --restart=Never --image=curlimages/curl -- curl -sf -m 5 http://s5-frontend.incidents

summary
