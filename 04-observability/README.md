# Domain 4 – Observability and Operations (20 %)

Kompetenzen laut Curriculum:
- Monitoring-, Alerting-, Logging- und Tracing-Lösungen implementieren
- Plattform-Effizienz mit Deployment-Metriken und Performance-Indikatoren messen und verbessern
- Plattform-Probleme und Incident-Szenarien diagnostizieren und beheben

Benötigte Tools: `./setup/install.sh prometheus jaeger_otel` (+ `argocd` für 4.6)

Zugriff:
```bash
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090 &
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n observability port-forward svc/jaeger 16686 &
```

Demo-App für diese Domain:
```bash
kubectl create ns demo
kubectl -n demo create deploy podinfo --image=ghcr.io/stefanprodan/podinfo:6.7.0 --port=9898
kubectl -n demo expose deploy podinfo --port=9898 --name=podinfo
kubectl -n demo patch svc podinfo --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/name","value":"http"}]'
```
podinfo stellt Prometheus-Metriken unter `:9898/metrics` bereit.

---

## Aufgabe 4.1 – ServiceMonitor ⏱ 5 Min.

1. Erstelle einen `ServiceMonitor` `podinfo` im Namespace `demo`, der den Service `podinfo`
   (Port-Name `http`, Pfad `/metrics`) alle 15 s scrapt.
2. Prüfe in Prometheus unter *Status → Targets*, dass das Target `UP` ist.
3. Was müsstest du tun, wenn das Helm-Chart nur ServiceMonitors mit dem Label
   `release: kps` auswählt?

---

## Aufgabe 4.2 – PromQL ⏱ 8 Min.

Schreibe PromQL-Queries und speichere sie in `/tmp/promql.txt` (eine pro Zeile):
1. CPU-Verbrauch (Cores) pro Namespace, letzte 5 Minuten
2. Memory Working Set pro Pod im Namespace `demo`
3. Top 5 Container nach Restarts in der letzten Stunde
4. Request-Rate von podinfo pro Statuscode (Metrik `http_requests_total`)
5. p95-Latenz von podinfo (Histogram `http_request_duration_seconds`)
6. Anteil der Pods pro Namespace, die nicht `Running` sind

---

## Aufgabe 4.3 – Alerting mit PrometheusRule ⏱ 8 Min.

Erstelle eine `PrometheusRule` `platform-alerts` im Namespace `monitoring` mit:
1. `PodCrashLooping` – Severity `critical`: mehr als 3 Restarts eines Containers in 15 Min., für 5 Min.
2. `HighErrorRate` – Severity `warning`: Anteil 5xx an allen podinfo-Requests > 5 % für 10 Min.
3. Eine **Recording Rule** `namespace:container_cpu_usage:sum_rate5m`.
4. Annotations `summary` und `description` mit Templating (`{{ $labels.pod }}`, `{{ $value }}`).

Prüfe mit `kubectl -n monitoring get prometheusrule` und in Prometheus unter *Alerts*.
Bonus: Konfiguriere eine `AlertmanagerConfig`, die `critical`-Alerts an einen Webhook
`http://alert-sink.monitoring:8080` schickt.

---

## Aufgabe 4.4 – Grafana-Dashboard als Code ⏱ 6 Min.

Erstelle eine ConfigMap `podinfo-dashboard` im Namespace `monitoring` mit dem Label
`grafana_dashboard: "1"`, die ein Dashboard „Podinfo“ mit zwei Panels enthält:
Request-Rate und p95-Latenz. Prüfe, dass es in Grafana automatisch erscheint.

---

## Aufgabe 4.5 – Tracing mit OpenTelemetry & Jaeger ⏱ 10 Min.

1. Deploye einen **OpenTelemetry Collector** (Deployment + ConfigMap + Service) `otel-collector`
   im Namespace `observability`:
   - Receiver: OTLP gRPC (4317) und HTTP (4318)
   - Processor: `batch`, `memory_limiter`
   - Exporter: OTLP an `jaeger.observability:4317` (TLS deaktiviert) und `debug`
2. Konfiguriere podinfo so, dass es Traces an den Collector sendet
   (`--otel-service-name=podinfo`, Env `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`).
3. Erzeuge Requests und finde die Traces in der Jaeger-UI unter Service `podinfo`.

---

## Aufgabe 4.6 – DORA-/Deployment-Metriken ⏱ 8 Min.

Argo CD exportiert Prometheus-Metriken (z. B. `argocd_app_sync_total`, `argocd_app_info`).
1. Erstelle einen ServiceMonitor für die Argo CD Application-Controller-Metriken.
2. Schreibe Queries für:
   - **Deployment Frequency:** erfolgreiche Syncs pro App in den letzten 7 Tagen
   - **Change Failure Rate:** fehlgeschlagene / alle Syncs (7 Tage)
   - Anzahl Apps, die gerade `OutOfSync` oder nicht `Healthy` sind
3. Erkläre: Wie würdest du **Lead Time for Changes** und **MTTR** messen?

---

## Aufgabe 4.7 – Incident-Szenarien ⏱ je 3–5 Min.

```bash
kubectl apply -f 04-observability/scenarios/
```
Im Namespace `incidents` laufen sieben defekte Workloads. Finde jeweils Ursache und
behebe sie, **ohne** die Lösung anzusehen. Ziel: < 25 Minuten für alle.

| Workload | Symptom |
|----------|---------|
| `s1-web` | Pods starten nicht |
| `s2-api` | Pods starten ständig neu |
| `s3-worker` | Pods werden immer wieder beendet |
| `s4-batch` | Pods bleiben `Pending` |
| `s5-frontend` | Pods laufen, aber der Service liefert nichts |
| `s6-cache` | Pods laufen, sind aber nie `Ready` |
| `s7-report` | Rollout hängt |

Nützlich: `kubectl get events --sort-by=.lastTimestamp`, `kubectl describe`,
`kubectl logs --previous`, `kubectl get endpoints`, `kubectl rollout status`.

---

✅ Prüfen: `./04-observability/verify.sh`
📖 Lösungen: [`solutions/`](solutions/)
