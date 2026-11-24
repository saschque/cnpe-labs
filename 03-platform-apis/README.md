# Domain 3 – Platform APIs and Self-Service Capabilities (25 %)

Kompetenzen laut Curriculum:
- Custom Resource Definitions (CRDs) für Plattform-Services entwerfen und erstellen
- Workflows für Self-Service-Provisioning über Plattform-APIs implementieren
- Kubernetes-Operatoren für Plattform-Automatisierung und Integration nutzen
- Automatisierungs-Frameworks für Self-Service-Provisioning nutzen

Benötigte Tools: `./setup/install.sh crossplane kyverno argo_workflows`

> **Mentales Modell Crossplane:** XRD = Schema (die API) · XR = Instanz (der Antrag) ·
> Composition = Rezept (was daraus gebaut wird) · Function = Logik im Rezept.
> Die Lösungen nutzen **Crossplane v2** (namespaced XRs, keine Claims). Für v1 siehe Hinweise
> in den Lösungen – prüfe in der Prüfung mit `kubectl get crd | grep crossplane` und
> `helm list -A`, welche Version läuft.

---

## Aufgabe 3.1 – CRD entwerfen ⏱ 10 Min.

Erstelle eine CRD für die Plattform-API `databases.platform.example.org`:
- Kind `Database`, Plural `databases`, Short Name `db`, Kategorie `platform`, **namespaced**
- Version `v1alpha1` (served, storage)
- `spec`:
  - `engine` – Pflicht, Enum `postgres` | `mysql`
  - `version` – String, Pflicht
  - `storageGB` – Integer, 1–100, Default 10
  - `highAvailability` – Boolean, Default `false`
- `status`-Subresource mit Feld `phase` (String)
- Zusätzliche Spalten in `kubectl get db`: `ENGINE`, `VERSION`, `PHASE`, `AGE`

Teste: Ein Objekt mit `engine: oracle` oder `storageGB: 500` muss abgelehnt werden.

---

## Aufgabe 3.2 – CEL-Validierung & Versionierung ⏱ 7 Min.

Erweitere die CRD aus 3.1:
1. Regel per `x-kubernetes-validations`: Wenn `highAvailability: true`, dann muss
   `storageGB >= 20` sein. Fehlermeldung: „HA benötigt mindestens 20 GB“.
2. `engine` darf nach dem Anlegen **nicht mehr geändert** werden (Immutable-Regel mit `oldSelf`).
3. Füge eine Version `v1beta1` hinzu (served, **nicht** storage). Markiere `v1alpha1` als
   `deprecated` mit einer Warnung.

---

## Aufgabe 3.3 – Crossplane: Eigene Plattform-API mit Composition ⏱ 15 Min.

Entwickler sollen mit einem einzigen Objekt eine Web-App bestellen können:

```yaml
apiVersion: platform.example.org/v1alpha1
kind: WebApp
metadata:
  name: shop
  namespace: team-a
spec:
  image: nginx:1.27
  replicas: 2
  port: 80
```

1. Installiere die Function `function-patch-and-transform`.
2. Erlaube Crossplane, Deployments und Services zu verwalten (RBAC, aggregierte ClusterRole).
3. Erstelle die XRD `webapps.platform.example.org` (namespaced, Felder `image` (Pflicht),
   `replicas` (Default 1), `port` (Default 80); Status-Feld `url`).
4. Erstelle eine Composition `webapp-basic` (Pipeline-Modus), die ein **Deployment** und
   einen **Service** erzeugt. `image`, `replicas` und `port` werden gepatcht. Schreibe die
   interne URL `http://<name>.<namespace>.svc` in `status.url`.
5. Lege die WebApp `shop` an und prüfe mit `crossplane beta trace webapp shop -n team-a`.

---

## Aufgabe 3.4 – Crossplane Troubleshooting ⏱ 7 Min.

```bash
kubectl apply -f 03-platform-apis/solutions/3.4-broken-webapp.yaml
```
Die WebApp `broken` wird nicht `Ready`. Finde die Ursache(n). Nützliche Befehle:
`kubectl describe webapp`, `crossplane beta trace`, `kubectl get composition`,
`kubectl -n crossplane-system logs deploy/crossplane`, `kubectl get functions`.

---

## Aufgabe 3.5 – Mit Operatoren arbeiten ⏱ 6 Min.

Crossplane, Argo CD, Flux, Kyverno … sind alle Operatoren. Beantworte per `kubectl`:
1. Welche CRDs bringt Argo CD mit? (`kubectl api-resources --api-group=argoproj.io`)
2. Welcher Controller reconciled `Application`-Objekte, und mit welchem ServiceAccount läuft er?
3. Welche Rechte hat dieser ServiceAccount cluster-weit? (`kubectl auth can-i --list --as=...`)
4. Nutze `kubectl explain application.spec.syncPolicy --recursive` und
   `kubectl explain webapp.spec`, um Felder einer CRD ohne Doku zu ermitteln.
5. Setze den Argo CD Application-Controller auf Log-Level `debug`, ohne Helm zu nutzen
   (Tipp: ConfigMap `argocd-cmd-params-cm`).

---

## Aufgabe 3.6 – Self-Service-Namespaces mit Kyverno `generate` ⏱ 8 Min.

Wenn ein Entwickler einen Namespace mit dem Label `platform.example.org/tenant=true` und
`team=<name>` anlegt, soll die Plattform **automatisch** erzeugen:
- eine `ResourceQuota` `tenant-quota` (requests.cpu 2, requests.memory 4Gi)
- eine `NetworkPolicy` `default-deny` (Ingress)
- eine `RoleBinding` `team-edit`, die der Gruppe `<team>-devs` die ClusterRole `edit` gibt

Die generierten Ressourcen sollen synchron gehalten werden (`synchronize: true`).

---

## Aufgabe 3.7 – Self-Service-Workflow mit Argo Workflows ⏱ 10 Min.

Erstelle ein `WorkflowTemplate` `provision-tenant` im Namespace `argo` mit den Parametern
`team` und `cpu`. Der Workflow soll:
1. Den Namespace `tenant-<team>` mit den Labels aus 3.6 anlegen (Ressource-Template, `action: create`)
2. Warten, bis die ResourceQuota existiert (Kyverno hat sie generiert)
3. Die WebApp `welcome` (aus 3.3) im neuen Namespace anlegen

Der Workflow-ServiceAccount braucht dafür passende Rechte – erstelle sie.

---

## Aufgabe 3.8 – RBAC für die Plattform-API ⏱ 5 Min.

Entwickler der Gruppe `team-a-devs` sollen im Namespace `team-a`
- `webapps` **erstellen, ändern, löschen und lesen** dürfen,
- `deployments` und `services` nur **lesen** dürfen.

Erstelle `Role` `webapp-author` und `RoleBinding` und prüfe beide Fälle mit `kubectl auth can-i`.

---

✅ Prüfen: `./03-platform-apis/verify.sh`
📖 Lösungen: [`solutions/`](solutions/)
