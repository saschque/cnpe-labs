# CNPE Practice – Übungsaufgaben für den Certified Cloud Native Platform Engineer

Hands-on-Übungen für die **CNPE**-Prüfung der Linux Foundation / CNCF.
Die Prüfung ist **performance-basiert** (ca. 15–20 Aufgaben in 120 Minuten in einer
Remote-Linux-Umgebung). Dieses Repo bildet die fünf offiziellen Domains nach.

| # | Domain | Gewicht | Ordner |
|---|--------|---------|--------|
| 1 | Platform Architecture and Infrastructure | 15 % | [`01-platform-architecture`](01-platform-architecture/) |
| 2 | GitOps and Continuous Delivery | 25 % | [`02-gitops-cd`](02-gitops-cd/) |
| 3 | Platform APIs and Self-Service Capabilities | 25 % | [`03-platform-apis`](03-platform-apis/) |
| 4 | Observability and Operations | 20 % | [`04-observability`](04-observability/) |
| 5 | Security and Policy Enforcement | 15 % | [`05-security-policy`](05-security-policy/) |

Dazu: [`mock-exam/`](mock-exam/) – eine komplette Probeprüfung (120 Min.) und
[`CHEATSHEET.md`](CHEATSHEET.md) – die wichtigsten Befehle auf einen Blick.

> ⚠️ Das offizielle Curriculum (github.com/cncf/curriculum) ist die Referenz. Prüfe vor
> der Prüfung, ob sich Domains oder Tool-Liste geändert haben.

## Tools in der Prüfungsumgebung

Argo CD · Argo Workflows · Crossplane · Flagger · Flux · Gatekeeper/OPA · Grafana ·
Istio · Jaeger · Kyverno · Linkerd · OpenCost · OpenTelemetry · Prometheus · Tekton –
plus `kubectl`, `helm`, `kustomize`, `git`, `jq`, `yq`.

## Schnellstart

```bash
# 1. Lokalen Cluster erstellen (kind, 1 Control-Plane + 2 Worker)
./setup/create-cluster.sh

# 2. Nur die Tools installieren, die du gerade übst (spart RAM)
./setup/install.sh argocd flux kyverno
./setup/install.sh all          # alles (≥ 16 GB RAM empfohlen)

# 3. Aufgaben bearbeiten
cat 01-platform-architecture/README.md

# 4. Ergebnis prüfen
./01-platform-architecture/verify.sh
```

Voraussetzungen: Docker, [kind](https://kind.sigs.k8s.io), kubectl, helm, git, jq.
Optional: `argocd`, `flux`, `tkn`, `argo`, `istioctl`, `linkerd`, `crossplane` CLIs.

## Aufbau jeder Domain

```
0X-domain/
├── README.md        # Aufgaben (Szenario, Anforderungen, Prüfkriterien)
├── solutions/       # Musterlösungen (erst NACH dem eigenen Versuch ansehen!)
└── verify.sh        # Automatischer Check deiner Lösung
```

## Lernstrategie

1. **Gewichtung beachten:** GitOps + Platform APIs = 50 % der Punkte.
2. **Doku-Navigation üben:** In der Prüfung hast du Zugriff auf die offiziellen Docs.
   Lege dir Bookmarks an und übe, Beispiele schnell zu finden und anzupassen.
3. **Imperativ, wo möglich:** `kubectl create ... --dry-run=client -o yaml` spart Zeit.
4. **Kaputt machen:** `04-observability/scenarios/` enthält absichtlich defekte
   Workloads – Fehlersuche unter Zeitdruck trainieren.
5. **Zeitmanagement:** Erst alle Aufgaben überfliegen, Quick Wins zuerst, schwierige
   Aufgaben markieren und später zurückkehren.
6. **Kontext!** Jede Aufgabe nennt Cluster/Namespace – in der Prüfung immer zuerst
   `kubectl config use-context ...` ausführen.

## Fortschritt

- [ ] Domain 1 – Platform Architecture
- [ ] Domain 2 – GitOps & CD
- [ ] Domain 3 – Platform APIs
- [ ] Domain 4 – Observability
- [ ] Domain 5 – Security & Policy
- [ ] Mock Exam < 120 Min. und ≥ 66 %
