# CNPE Mock Exam – 120 Minuten

**Regeln:** Timer auf 120 Min. stellen. Nur offizielle Doku (kubernetes.io, argo-cd.readthedocs.io,
fluxcd.io, crossplane.io, kyverno.io, open-policy-agent.github.io, istio.io, linkerd.io,
prometheus.io, opentelemetry.io, tekton.dev, argoproj.github.io, docs.flagger.app, opencost.io).
Keine Musterlösungen. Bestehensgrenze für dich: **66 von 100 Punkten**.

Vorbereitung (vor dem Timer):
```bash
./setup/create-cluster.sh
./setup/install.sh argocd flux argo_workflows tekton crossplane kyverno prometheus
./mock-exam/setup.sh
```

Tipp: Erst alle Aufgaben lesen, Quick Wins zuerst, schwere Aufgaben markieren.

---

### Aufgabe 1 – Mandanten-Quota (4 Punkte) · Domain 1
Namespace `mx-team-red` existiert. Erstelle eine ResourceQuota `red-quota` mit `requests.cpu: 3`,
`requests.memory: 6Gi`, `pods: 15` und eine LimitRange `red-defaults` mit Default-Requests
`50m`/`64Mi` und Default-Limits `250m`/`256Mi`.

### Aufgabe 2 – HPA (4 Punkte) · Domain 1
Erstelle für das Deployment `mx-team-red/api` einen HPA: 3–12 Replicas, CPU 70 %, Memory 80 %.

### Aufgabe 3 – NetworkPolicy (5 Punkte) · Domain 1
Im Namespace `mx-team-red` dürfen Pods mit `app=db` nur Traffic auf Port 5432 von Pods mit
`app=api` desselben Namespaces empfangen. Aller anderer Ingress zu `app=db` ist verboten.

### Aufgabe 4 – Argo CD Application (6 Punkte) · Domain 2
Erstelle die Application `mx-kustomize` (Projekt `default`), die
`https://github.com/argoproj/argocd-example-apps` Pfad `kustomize-guestbook` in den Namespace
`mx-gb` deployt. Auto-Sync mit Prune, Namespace automatisch anlegen, und setze per Kustomize-Option
der Application das `namePrefix` auf `mx-`.

### Aufgabe 5 – Argo CD Troubleshooting (6 Punkte) · Domain 2
Die Application `mx-broken` (von `setup.sh` angelegt) ist nicht `Synced/Healthy`. Repariere sie,
ohne die Application zu löschen.

### Aufgabe 6 – Flux (6 Punkte) · Domain 2
Deploye mit Flux das Helm-Chart `podinfo` (OCI `oci://ghcr.io/stefanprodan/charts`) als
HelmRelease `mx-podinfo` in den Namespace `mx-flux` mit `replicaCount: 3`. Die Reconciliation
soll alle 2 Minuten laufen.

### Aufgabe 7 – Argo Workflows (6 Punkte) · Domain 2
Erstelle im Namespace `argo` ein WorkflowTemplate `mx-pipeline` mit Parameter `env` (Default
`dev`) und den Schritten `test` → `deploy` (sequentiell, `steps`-Syntax), die jeweils
`echo <schritt> to <env>` ausgeben. Starte es einmal mit `env=staging`, der Workflow muss
`Succeeded` sein.

### Aufgabe 8 – Tekton (7 Punkte) · Domain 2
Erstelle im Namespace `ci` einen Task `mx-hello` mit Parameter `name`, der `Hallo <name>` in
ein **Result** `greeting` schreibt, und eine Pipeline `mx-greet`, die `mx-hello` ausführt und das
Result an einen zweiten Task `mx-print` (gibt das Result aus) übergibt. Starte einen
erfolgreichen PipelineRun.

### Aufgabe 9 – CRD (7 Punkte) · Domain 3
Erstelle die CRD `queues.messaging.example.org` (Kind `Queue`, namespaced, Short Name `q`,
Version `v1`) mit `spec.maxMessages` (Integer, Pflicht, 1–10000), `spec.fifo` (Boolean,
Default `false`) und einer Printer-Spalte `MAX`. Lege danach die Queue `orders` im Namespace
`mx-team-red` mit `maxMessages: 500` an.

### Aufgabe 10 – Crossplane (9 Punkte) · Domain 3
`setup.sh` hat eine XRD `buckets.storage.example.org` (Kind `Bucket`) installiert. Erstelle eine
Composition `bucket-configmap`, die für jeden `Bucket` eine **ConfigMap** mit dem Namen des
Buckets erzeugt, deren `data.size` den Wert von `spec.sizeGB` (als String!) enthält.
Lege anschließend den Bucket `logs` (`sizeGB: 50`) im Namespace `mx-team-red` an – er muss
`Ready` werden.
*Hinweis: Function `function-patch-and-transform` und RBAC für ConfigMaps sind schon vorhanden.*

### Aufgabe 11 – Self-Service mit Kyverno (6 Punkte) · Domain 3
Jeder neue Namespace mit dem Label `mx-tenant=true` soll automatisch eine ConfigMap
`platform-info` mit `data.contact: platform@example.org` erhalten (synchron gehalten).

### Aufgabe 12 – PrometheusRule (6 Punkte) · Domain 4
Erstelle eine PrometheusRule `mx-rules` im Namespace `monitoring` mit dem Alert
`DeploymentReplicasMismatch` (Severity `warning`), der feuert, wenn
`kube_deployment_spec_replicas` ≠ `kube_deployment_status_replicas_available` für 10 Minuten.

### Aufgabe 13 – Incident (7 Punkte) · Domain 4
Im Namespace `mx-incident` läuft die App `checkout` nicht korrekt (zwei Fehler). Repariere sie,
bis alle Pods `Ready` sind und der Service `checkout` Endpoints hat. Schreibe die beiden
Ursachen (je eine Zeile) nach `/tmp/mx-incident.txt`.

### Aufgabe 14 – Metrik-Query (4 Punkte) · Domain 4
Schreibe nach `/tmp/mx-query.txt` eine PromQL-Query, die die 3 Namespaces mit dem höchsten
Memory-Working-Set liefert.

### Aufgabe 15 – RBAC (5 Punkte) · Domain 5
ServiceAccount `mx-auditor` im Namespace `mx-team-red`: darf cluster-weit Pods, Deployments und
Events **lesen** (get/list/watch), aber keine Secrets. Erstelle die nötigen Objekte.

### Aufgabe 16 – Kyverno Policy (6 Punkte) · Domain 5
Erstelle eine ClusterPolicy `mx-require-limits` (Enforce), die Pods im Namespace
`mx-team-red` ablehnt, wenn ein Container kein Memory-Limit hat.

### Aufgabe 17 – Gatekeeper/PSA (6 Punkte) · Domain 5
Setze für den Namespace `mx-team-red` Pod Security Admission `enforce=restricted`.
Sorge dafür, dass das Deployment `mx-team-red/api` danach weiterhin neue Pods erzeugen kann
(passe sein Pod-Template an). *Achtung: Prüfe, ob das auch nach Aufgabe 16 noch passt.*

---

**Summe: 100 Punkte.** Lösungen: [`SOLUTIONS.md`](SOLUTIONS.md) · Auswertung: `./mock-exam/verify.sh`
