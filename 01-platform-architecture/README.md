# Domain 1 – Platform Architecture and Infrastructure (15 %)

Kompetenzen laut Curriculum:
- Best Practices für Networking, Storage und Compute anwenden
- Cost-Management-Lösungen für Right-Sizing und Scaling nutzen
- Multi-Tenancy-Ressourcennutzung optimieren

Benötigte Tools: `./setup/install.sh prometheus opencost` (nur für 1.6)

---

## Aufgabe 1.1 – Mandanten-Namespace mit Quota ⏱ 6 Min.

Das Team **payments** bekommt einen eigenen Namespace.

1. Erstelle den Namespace `team-payments` mit den Labels `team=payments` und `tier=prod`.
2. Erstelle eine `ResourceQuota` namens `payments-quota`:
   - `requests.cpu: 4`, `requests.memory: 8Gi`
   - `limits.cpu: 8`, `limits.memory: 16Gi`
   - max. `20` Pods, max. `5` PersistentVolumeClaims, max. `0` Services vom Typ LoadBalancer
3. Erstelle eine `LimitRange` namens `payments-defaults`, damit Container ohne Angaben
   automatisch `100m`/`128Mi` Requests und `500m`/`512Mi` Limits erhalten. Ein Container
   darf maximal `2` CPU und `2Gi` Memory als Limit anfordern.

**Prüfkriterium:** Ein Pod ohne `resources` lässt sich starten und hat danach die Defaults gesetzt.

---

## Aufgabe 1.2 – Horizontal Pod Autoscaler ⏱ 5 Min.

1. Erstelle im Namespace `team-payments` ein Deployment `checkout` (Image
   `registry.k8s.io/hpa-example`, 1 Replica, Request `cpu: 200m`, Port 80) und einen
   ClusterIP-Service `checkout` auf Port 80.
2. Erstelle einen HPA (`autoscaling/v2`) `checkout`: min. 2, max. 8 Replicas,
   Ziel-CPU-Auslastung 60 %.
3. Konfiguriere das Scale-Down-Verhalten: Stabilisierungsfenster 120 s, maximal
   1 Pod pro 60 s entfernen.

**Bonus:** Erzeuge Last und beobachte das Scaling:
```bash
kubectl -n team-payments run load --rm -it --image=busybox -- \
  sh -c 'while true; do wget -q -O- http://checkout; done'
```

---

## Aufgabe 1.3 – Verfügbarkeit: PriorityClass & PodDisruptionBudget ⏱ 5 Min.

1. Erstelle eine `PriorityClass` `platform-critical` mit Wert `1000000`, nicht global default,
   Beschreibung „Kritische Plattform-Komponenten“.
2. Patche das Deployment `checkout` so, dass es diese PriorityClass verwendet.
3. Erstelle ein `PodDisruptionBudget` `checkout-pdb`, das sicherstellt, dass immer
   mindestens 1 Pod von `checkout` verfügbar bleibt.
4. Verteile die `checkout`-Pods mit `topologySpreadConstraints` gleichmäßig über Nodes
   (`maxSkew: 1`, `whenUnsatisfiable: ScheduleAnyway`).

---

## Aufgabe 1.4 – Netzwerk-Isolation zwischen Mandanten ⏱ 7 Min.

1. Erstelle im Namespace `team-payments` eine NetworkPolicy `default-deny`, die
   **jeglichen** Ingress- und Egress-Traffic blockiert.
2. Erstelle eine NetworkPolicy `allow-dns`, die Egress zu CoreDNS (Namespace
   `kube-system`, Label `k8s-app=kube-dns`, UDP/TCP 53) erlaubt.
3. Erstelle eine NetworkPolicy `allow-from-frontend`, die Ingress zu Pods mit
   `app=checkout` auf Port 80 nur aus Namespaces mit dem Label `team=frontend` erlaubt.
4. Erlaube außerdem Ingress innerhalb des Namespaces (Pod-zu-Pod) – `allow-same-namespace`.

> Hinweis: kind's Standard-CNI (kindnet) unterstützt NetworkPolicies ab v0.24. Bei älteren
> Versionen Calico installieren, sonst haben die Policies keinen Effekt.

---

## Aufgabe 1.5 – Storage ⏱ 5 Min.

1. Erstelle eine StorageClass `fast-retain` mit dem Provisioner des Clusters
   (in kind: `rancher.io/local-path`), `reclaimPolicy: Retain`,
   `volumeBindingMode: WaitForFirstConsumer` und `allowVolumeExpansion: true`.
2. Erstelle im Namespace `team-payments` einen PVC `ledger-data` (1Gi, `ReadWriteOnce`)
   mit dieser StorageClass.
3. Erkläre (für dich), warum der PVC im Status `Pending` bleibt, bis ein Pod ihn nutzt.
   Erstelle dann einen Pod `ledger`, der den PVC unter `/data` mountet.

---

## Aufgabe 1.6 – Kosten mit OpenCost ⏱ 8 Min.

1. Stelle sicher, dass OpenCost läuft (`./setup/install.sh prometheus opencost`).
2. Ermittle über die OpenCost-API die Kosten der letzten 24 h, **aggregiert pro Namespace**,
   und speichere die Ausgabe in `/tmp/cost-by-namespace.json`.
3. Ermittle den Namespace mit den höchsten Gesamtkosten und schreibe nur dessen Namen nach
   `/tmp/top-namespace.txt`.
4. Bonus: Aggregiere stattdessen nach Label `team`.

---

## Aufgabe 1.7 – Right-Sizing ⏱ 6 Min.

Im Namespace `rightsizing` läuft ein überdimensioniertes Deployment:
```bash
kubectl apply -f 01-platform-architecture/solutions/rightsizing-setup.yaml
```
1. Ermittle mit `kubectl top pod` den tatsächlichen Verbrauch der Pods von `oversized`.
2. Passe die Requests so an, dass sie ca. dem 1,2-fachen des gemessenen Verbrauchs entsprechen
   (mindestens `10m` CPU / `16Mi` Memory). Setze das Memory-Limit auf das Doppelte des Requests,
   **kein** CPU-Limit.
3. Reduziere die Replicas von 6 auf 2.

---

## Aufgabe 1.8 – Self-Service-Mandanten mit Kustomize ⏱ 8 Min.

Erstelle unter `/tmp/tenants/` eine Kustomize-Struktur:
```
/tmp/tenants/
├── base/          # Namespace, ResourceQuota, LimitRange, default-deny NetworkPolicy, RoleBinding
└── overlays/
    ├── team-a/    # Namespace team-a, Quota requests.cpu=2
    └── team-b/    # Namespace team-b, Quota requests.cpu=6
```
- Die RoleBinding gibt der Gruppe `<team>-devs` die ClusterRole `edit` im Namespace.
- Wende beide Overlays mit `kubectl apply -k` an.

**Prüfkriterium:** `kubectl auth can-i create deploy -n team-a --as=x --as-group=team-a-devs` → `yes`.

---

✅ Prüfen: `./01-platform-architecture/verify.sh`
📖 Lösungen: [`solutions/`](solutions/)
