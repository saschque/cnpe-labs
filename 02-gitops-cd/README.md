# Domain 2 – GitOps and Continuous Delivery (25 %)

Kompetenzen laut Curriculum:
- GitOps-Workflows für Applikations- und Infrastruktur-Deployments implementieren
- CI/CD-Pipelines mit Kubernetes-Integration bauen und konfigurieren
- Argo Workflows für Plattform-Automatisierung nutzen
- Applikationen mit Progressive-Delivery-Strategien ausrollen

Benötigte Tools: `./setup/install.sh argocd flux tekton argo_workflows`
Für 2.8: `./setup/install.sh prometheus istio flagger`

Öffentliche Beispiel-Repos:
- `https://github.com/argoproj/argocd-example-apps` (Pfade: `guestbook`, `helm-guestbook`, `kustomize-guestbook`)
- `https://github.com/stefanprodan/podinfo` (Kustomize unter `./kustomize`, Helm-Chart unter `oci://ghcr.io/stefanprodan/charts/podinfo`)

---

## Aufgabe 2.1 – Argo CD Application ⏱ 6 Min.

Erstelle eine Argo CD `Application` namens `guestbook` im Namespace `argocd`:
- Quelle: `argocd-example-apps`, Pfad `guestbook`, Revision `HEAD`
- Ziel: In-Cluster, Namespace `guestbook` (soll automatisch angelegt werden)
- Automatischer Sync mit `prune` und `selfHeal`

**Prüfkriterium:** Status `Synced` / `Healthy`. Lösche danach manuell das Deployment
`guestbook-ui` und beobachte, wie Argo CD es wiederherstellt.

---

## Aufgabe 2.2 – ApplicationSet für mehrere Umgebungen ⏱ 8 Min.

Erstelle ein `ApplicationSet` `guestbook-envs`, das per **List-Generator** drei
Applications erzeugt: `guestbook-dev`, `guestbook-staging`, `guestbook-prod`.
- Quelle: Pfad `helm-guestbook`
- Ziel-Namespace jeweils `gb-<env>`, automatisch anlegen
- Helm-Parameter `replicaCount`: dev=1, staging=2, prod=3
- Nur `dev` und `staging` syncen automatisch, `prod` manuell.

---

## Aufgabe 2.3 – Sync Waves & Hooks ⏱ 6 Min.

Unter `solutions/2.3-waves/` liegen Manifeste ohne Annotations. Ergänze sie, sodass Argo CD
in dieser Reihenfolge synct:
1. Namespace + ConfigMap (Wave `-1`)
2. Ein `Job` `db-migrate` als **PreSync-Hook**, der nach Erfolg gelöscht wird
3. Deployment (Wave `0`)
4. Ein `Job` `smoke-test` als **PostSync-Hook**

Beantworte: Was passiert mit dem Deployment, wenn `db-migrate` fehlschlägt?

---

## Aufgabe 2.4 – Flux: GitRepository + Kustomization ⏱ 6 Min.

1. Erstelle im Namespace `flux-system` eine `GitRepository` `podinfo`
   (URL `https://github.com/stefanprodan/podinfo`, Branch `master`, Intervall 1m).
2. Erstelle eine Flux `Kustomization` `podinfo`, die den Pfad `./kustomize` in den
   Namespace `podinfo` deployt, mit `prune: true`, Intervall 5m und einem Health-Check auf
   das Deployment `podinfo`.
3. Pausiere die Reconciliation, ändere manuell die Replicas, setze fort und erzwinge eine
   sofortige Reconciliation.

---

## Aufgabe 2.5 – Flux: HelmRelease ⏱ 6 Min.

1. Erstelle eine `HelmRepository` vom Typ **OCI** `podinfo` für
   `oci://ghcr.io/stefanprodan/charts`.
2. Erstelle eine `HelmRelease` `podinfo-helm` im Namespace `podinfo-helm`, Chart `podinfo`,
   Version `>=6.0.0`, mit den Values `replicaCount: 2` und `ui.message: "Hallo CNPE"`.
3. Konfiguriere: bei Fehlschlag max. 3 Upgrade-Versuche, danach Rollback.

---

## Aufgabe 2.6 – Troubleshooting: App hängt in OutOfSync/Degraded ⏱ 7 Min.

```bash
kubectl apply -f 02-gitops-cd/solutions/2.6-broken-app.yaml
```
Die Application `broken-app` synct nicht. Finde **alle** Fehler und behebe sie, bis sie
`Synced`/`Healthy` ist. Nutze `argocd app get`, `kubectl describe application` und die
Conditions.

---

## Aufgabe 2.7 – Tekton-Pipeline ⏱ 10 Min.

1. Erstelle einen Tekton-`Task` `lint-yaml` im Namespace `ci`, der einen Parameter `path`
   hat und im Image `cytopia/yamllint` den Befehl `yamllint -d relaxed $(params.path)` auf einem
   Workspace `source` ausführt.
2. Erstelle eine `Pipeline` `ci-pipeline` mit zwei Tasks:
   - `clone`: klont ein Git-Repo (Parameter `repo-url`) in den Workspace – nutze ein
     einfaches `alpine/git`-Image (kein Hub-Task nötig)
   - `lint`: läuft **nach** `clone` und nutzt `lint-yaml`
3. Starte einen `PipelineRun` gegen `https://github.com/argoproj/argocd-example-apps`
   mit Pfad `guestbook`, Workspace über `volumeClaimTemplate` (1Gi).
4. Lies die Logs mit `tkn pipelinerun logs --last -f` (oder kubectl).

---

## Aufgabe 2.8 – Argo Workflows ⏱ 10 Min.

1. Erstelle im Namespace `argo` ein `WorkflowTemplate` `platform-dag` mit einem DAG:
   ```
        validate
        /      \
   build-a   build-b
        \      /
        publish
   ```
   Jeder Schritt nutzt ein Template `echo` (Image `alpine`, gibt den Parameter `msg` aus).
2. Starte einen Workflow aus dem Template (`argo submit --from workflowtemplate/platform-dag`).
3. Erstelle einen `CronWorkflow` `nightly-cleanup`, der täglich um 02:00 (Europe/Berlin)
   läuft, `concurrencyPolicy: Forbid` hat und die letzten 3 erfolgreichen Runs behält.
4. Bonus: Füge einem Schritt `retryStrategy` (limit 3, Backoff) hinzu.

---

## Aufgabe 2.9 – Progressive Delivery mit Flagger (Canary) ⏱ 12 Min.

Voraussetzung: Istio + Prometheus + Flagger installiert.
1. Erstelle den Namespace `canary-demo` mit Istio-Sidecar-Injection.
2. Deploye `podinfo` (Image `ghcr.io/stefanprodan/podinfo:6.7.0`, Port 9898) **ohne** Service.
3. Erstelle eine Flagger-`Canary` `podinfo`:
   - Analyse-Intervall 30s, Schwelle 5 Fehlschläge, max. Gewicht 50, Schrittweite 10
   - Metriken: `request-success-rate` min. 99 %, `request-duration` max. 500 ms
4. Löse einen Canary-Rollout aus, indem du das Image auf `6.7.1` aktualisierst, und
   beobachte ihn mit `kubectl -n canary-demo describe canary podinfo`.
5. Wie würdest du das Ganze auf **Blue/Green** umstellen? (Stichwort `iterations`)

---

✅ Prüfen: `./02-gitops-cd/verify.sh`
📖 Lösungen: [`solutions/`](solutions/)
