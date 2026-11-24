# Domain 4 – Observability and Operations (20 %)

Competencies from the curriculum:
- Implementing monitoring, alerting, logging, and tracing solutions
- Measuring and improving platform efficiency using deployment metrics and performance indicators
- Diagnosing and remediating platform issue and incident scenarios

Tools needed: `./setup/install.sh prometheus jaeger_otel` (+ `argocd` for 4.6)

Access:
```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090 &
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n observability port-forward svc/jaeger 16686 &
```

Demo app for this domain:
```bash
kubectl create ns demo
kubectl -n demo create deploy podinfo --image=ghcr.io/stefanprodan/podinfo:6.7.0 --port=9898
kubectl -n demo expose deploy podinfo --port=9898 --name=podinfo
kubectl -n demo patch svc podinfo --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/name","value":"http"}]'
```
podinfo exposes Prometheus metrics at `:9898/metrics`.

---

## Task 4.1 – ServiceMonitor ⏱ 5 min

1. Create a `ServiceMonitor` `podinfo` in namespace `demo` that scrapes the service `podinfo`
   (port name `http`, path `/metrics`) every 15 s.
2. Check in Prometheus under *Status → Targets* that the target is `UP`.
3. What would you have to do if the Helm chart only selects ServiceMonitors with the label
   `release: kps`?

---

## Task 4.2 – PromQL ⏱ 8 min

Write PromQL queries and save them to `/tmp/promql.txt` (one per line):
1. CPU usage (cores) per namespace, last 5 minutes
2. Memory working set per pod in namespace `demo`
3. Top 5 containers by restarts in the last hour
4. Request rate of podinfo per status code (metric `http_requests_total`)
5. p95 latency of podinfo (histogram `http_request_duration_seconds`)
6. Share of pods per namespace that are not `Running`

---

## Task 4.3 – Alerting with PrometheusRule ⏱ 8 min

Create a `PrometheusRule` `platform-alerts` in namespace `monitoring` with:
1. `PodCrashLooping` – severity `critical`: more than 3 restarts of a container in 15 min, for 5 min.
2. `HighErrorRate` – severity `warning`: share of 5xx among all podinfo requests > 5 % for 10 min.
3. A **recording rule** `namespace:container_cpu_usage:sum_rate5m`.
4. Annotations `summary` and `description` with templating (`{{ $labels.pod }}`, `{{ $value }}`).

Check with `kubectl -n monitoring get prometheusrule` and in Prometheus under *Alerts*.
Bonus: configure an `AlertmanagerConfig` that sends `critical` alerts to a webhook
`http://alert-sink.monitoring:8080`.

---

## Task 4.4 – Grafana dashboard as code ⏱ 6 min

Create a ConfigMap `podinfo-dashboard` in namespace `monitoring` with the label
`grafana_dashboard: "1"` that contains a dashboard "Podinfo" with two panels: request rate and
p95 latency. Check that it shows up in Grafana automatically.

---

## Task 4.5 – Tracing with OpenTelemetry & Jaeger ⏱ 10 min

1. Deploy an **OpenTelemetry Collector** (Deployment + ConfigMap + Service) `otel-collector`
   in namespace `observability`:
   - Receiver: OTLP gRPC (4317) and HTTP (4318)
   - Processors: `batch`, `memory_limiter`
   - Exporters: OTLP to `jaeger.observability:4317` (TLS disabled) and `debug`
2. Configure podinfo to send traces to the collector
   (`--otel-service-name=podinfo`, env `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`).
3. Generate requests and find the traces in the Jaeger UI under the service `podinfo`.

---

## Task 4.6 – DORA / deployment metrics ⏱ 8 min

Argo CD exports Prometheus metrics (e.g. `argocd_app_sync_total`, `argocd_app_info`).
1. Create a ServiceMonitor for the Argo CD application controller metrics.
2. Write queries for:
   - **Deployment frequency:** successful syncs per app over the last 7 days
   - **Change failure rate:** failed / all syncs (7 days)
   - Number of apps that are currently `OutOfSync` or not `Healthy`
3. Explain: How would you measure **lead time for changes** and **MTTR**?

---

## Task 4.7 – Incident scenarios ⏱ 3–5 min each

```bash
kubectl apply -f 04-observability/scenarios/incidents.yaml
```
Seven broken workloads run in namespace `incidents`. Find the cause of each and fix it
**without** looking at the solution. Goal: < 25 minutes for all of them.

| Workload | Symptom |
|----------|---------|
| `s1-web` | Pods don't start |
| `s2-api` | Pods restart constantly |
| `s3-worker` | Pods keep getting terminated |
| `s4-batch` | Pods stay `Pending` |
| `s5-frontend` | Pods run, but the service returns nothing |
| `s6-cache` | Pods run but are never `Ready` |
| `s7-report` | Rollout is stuck |

Useful: `kubectl get events --sort-by=.lastTimestamp`, `kubectl describe`,
`kubectl logs --previous`, `kubectl get endpoints`, `kubectl rollout status`.

---

# More exercises

## Task 4.8 – PodMonitor ⏱ 5 min

Not every app has a service. Scrape the podinfo pods in namespace `demo` **directly**:
1. Name the container port 9898 of the Deployment `podinfo` `http-metrics`.
2. Create a `PodMonitor` `podinfo-pods` that scrapes pods with `app=podinfo` on this port every
   30 s and copies the pod label `app` into the Prometheus label `application`.

---

## Task 4.9 – Analyzing logs ⏱ 6 min

```bash
kubectl apply -f 04-observability/solutions/4.9-logs-setup.yaml
```
In namespace `logs-demo`, three `chatty` pods write INFO, WARN and ERROR lines.
1. Count all `ERROR` lines of **all** pods in the last 10 minutes → `/tmp/error-count.txt` (just the number).
2. Find the pod with the most errors → `/tmp/noisy-pod.txt`.
3. The `sidecar` container of the same pod also writes logs. How do you read only that one, or
   all containers at once with a pod prefix?

---

## Task 4.10 – SLOs and burn-rate alerts ⏱ 10 min

podinfo has an availability SLO of **99.9 %** (share of non-5xx requests).
Create a `PrometheusRule` `podinfo-slo` in namespace `monitoring` with:
1. Recording rules `sli:podinfo_errors:ratio_rate5m`, `…_rate1h`, `…_rate6h`
   (error ratio in each window).
2. Alert `PodinfoErrorBudgetBurnFast` (critical): burn rate > 14.4 in the 1h **and** 5m windows.
3. Alert `PodinfoErrorBudgetBurnSlow` (warning): burn rate > 6 in the 6h **and** 1h windows
   (simplified: use the 1h window as the short window).

Explain: Why two windows per alert?

---

## Task 4.11 – RED metrics from traces ⏱ 8 min

Extend the OTel Collector from 4.5:
1. Add the `spanmetrics` **connector**: it receives spans from the traces pipeline and turns
   them into metrics (requests, errors, duration).
2. Export these metrics with the `prometheus` exporter on port `8889`.
3. Expose the port through the service `otel-collector` and create a ServiceMonitor
   `otel-collector` so Prometheus collects the metrics.
4. Find the metric with the calls per service in Prometheus (`traces_span_metrics_calls_total`
   or `calls_total`, depending on the collector version).

---

## Task 4.12 – Incident scenarios, round 2 ⏱ 3–5 min each

```bash
kubectl apply -f 04-observability/scenarios/incidents-2.yaml
```
In namespace `incidents-2`:

| Workload | Symptom |
|----------|---------|
| `s8-billing` | Pods don't start |
| `s9-search` | Pods restart every few seconds although the app works |
| `s10-uploads` | Pod stays `Pending` |
| `s11-sync` | Pods crash-loop, logs show an HTTP error from the Kubernetes API |
| `s12-resolver` | Pods crash-loop, logs show name resolution errors |

Goal: all five in < 20 minutes. Don't change namespace-wide policies in a way that would open
up other workloads – fix things as narrowly as possible.

---

✅ Check: `./04-observability/verify.sh`
📖 Solutions: [`solutions/`](solutions/)
