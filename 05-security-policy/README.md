# Domain 5 – Security and Policy Enforcement (15 %)

Kompetenzen laut Curriculum:
- Sichere Service-zu-Service-Kommunikation konfigurieren
- RBAC und Security Controls über Plattform-Ressourcen anwenden
- Audit Trails erzeugen und Policy-Compliance durchsetzen (SBOM, Compliance-Reports …)
- Policy Engines und Admission Controller für Governance nutzen
- Security-Scanning und Compliance-Checks in Deployment-Pipelines integrieren

Benötigte Tools: `./setup/install.sh istio kyverno gatekeeper tekton`
(Kyverno und Gatekeeper parallel ist möglich, aber übe sie besser nacheinander.)

---

## Aufgabe 5.1 – mTLS mit Istio ⏱ 8 Min.

1. Erstelle die Namespaces `shop` (mit Sidecar-Injection) und `legacy` (ohne).
2. Deploye in beiden Namespaces `httpbin` (Image `kennethreitz/httpbin`, Port 80, Service
   `httpbin`) und in beiden einen `curl`-Client (Deployment `sleep`, Image `curlimages/curl`,
   Kommando `sleep infinity`).
3. Erzwinge im Namespace `shop` **STRICT** mTLS (`PeerAuthentication` `default`).
4. Zeige: `legacy/sleep → shop/httpbin` schlägt fehl, `shop/sleep → shop/httpbin` funktioniert.

---

## Aufgabe 5.2 – Istio AuthorizationPolicy ⏱ 7 Min.

Im Namespace `shop`:
1. Erstelle eine `AuthorizationPolicy` `deny-all` (leere Spec) – nichts geht mehr.
2. Erstelle eine `AuthorizationPolicy` `allow-sleep-get`, die für `app=httpbin` nur
   `GET`-Requests auf `/get` und `/headers` vom ServiceAccount `shop/sleep` erlaubt.
3. Teste: `GET /get` → 200, `POST /post` → 403.

---

## Aufgabe 5.3 – Linkerd (Alternative) ⏱ 6 Min.

Falls die Prüfung Linkerd statt Istio nutzt:
1. Injiziere Linkerd in den Namespace `mesh-demo` (Annotation).
2. Prüfe mit `linkerd viz edges` / `linkerd diagnostics` bzw. `linkerd check --proxy`, dass mTLS aktiv ist.
3. Erstelle einen `Server` + `AuthorizationPolicy` + `MeshTLSAuthentication`, der nur
   Clients mit dem ServiceAccount `frontend` den Zugriff auf Port 80 von `backend` erlaubt.

---

## Aufgabe 5.4 – RBAC & ServiceAccounts ⏱ 6 Min.

1. Erstelle im Namespace `ci` den ServiceAccount `deployer`.
2. Er darf in den Namespaces `gb-dev` und `gb-staging` Deployments `get/list/patch/update`,
   aber **nicht** löschen. Nutze **eine** ClusterRole `deployment-updater` und zwei RoleBindings.
3. Er darf cluster-weit Namespaces lesen.
4. Deaktiviere das automatische Mounten des Tokens für den ServiceAccount.
5. Prüfe alles mit `kubectl auth can-i --as=system:serviceaccount:ci:deployer`.
6. Erzeuge ein zeitlich begrenztes Token (10 Min.) für den ServiceAccount.

---

## Aufgabe 5.5 – Pod Security Admission ⏱ 4 Min.

1. Erstelle den Namespace `secure-apps` und setze PSA-Labels: `enforce=baseline`, `warn=restricted`,
   `audit=restricted` (jeweils Version `latest`).
2. Versuche, einen privilegierten Pod anzulegen – er muss abgelehnt werden.
3. Schreibe ein Pod-Manifest, das **restricted** erfüllt.

---

## Aufgabe 5.6 – Kyverno-Policies ⏱ 12 Min.

Erstelle folgende `ClusterPolicy`s:
1. `require-team-label` (**Enforce**): Deployments müssen das Label `team` haben.
   Ausnahme: Namespaces `kube-system`, `argocd`, `flux-system`.
2. `disallow-latest-tag` (**Enforce**): Container-Images müssen einen Tag haben und dürfen
   nicht `:latest` sein.
3. `add-default-resources` (**Mutate**): Fügt Containern ohne `resources.requests`
   `cpu: 100m`, `memory: 128Mi` hinzu.
4. `require-probes` (**Audit**): Deployments sollten eine `readinessProbe` haben.
5. Zeige die Verstöße von 4. als `PolicyReport` an (`kubectl get policyreport -A`).
6. Erstelle eine `PolicyException` für das Deployment `legacy-app` im Namespace `legacy`
   für `require-team-label`.

---

## Aufgabe 5.7 – OPA Gatekeeper ⏱ 10 Min.

1. Erstelle ein `ConstraintTemplate` `K8sRequiredLabels` (Rego), das prüft, ob bestimmte
   Labels vorhanden sind (Parameter: Liste `labels`).
2. Erstelle einen Constraint `ns-must-have-owner`, der für **Namespaces** das Label `owner`
   verlangt – zunächst mit `enforcementAction: dryrun`.
3. Lies die Audit-Ergebnisse (`status.violations`) des Constraints aus.
4. Stelle auf `deny` um und teste.
5. Bonus: Erstelle ein `ConstraintTemplate` `K8sAllowedRepos`, das nur Images aus
   `ghcr.io/` und `registry.k8s.io/` erlaubt.

---

## Aufgabe 5.8 – Audit Trail ⏱ 5 Min.

Der kind-Cluster schreibt ein API-Audit-Log (siehe `setup/audit-policy.yaml`).
1. Lösche ein Deployment und finde den Audit-Eintrag: Wer hat wann was gelöscht?
2. Finde alle Änderungen an RoleBindings der letzten Stunde.
3. Erkläre die Audit-Level `None`, `Metadata`, `Request`, `RequestResponse`.
   Warum loggt man Secrets nur mit `Metadata`?

---

## Aufgabe 5.9 – Security-Scanning in der Pipeline ⏱ 12 Min.

Erweitere die Tekton-Pipeline aus 2.7 (Namespace `ci`) um:
1. Task `trivy-scan`: scannt ein Image (Parameter `image`) mit `aquasec/trivy` und
   **bricht ab**, wenn `CRITICAL`-Schwachstellen gefunden werden.
2. Task `sbom`: erzeugt mit `anchore/syft` ein SBOM im Format **SPDX-JSON** und legt es
   im Workspace unter `sbom/` ab.
3. Task `kyverno-test`: prüft die Manifeste im Repo mit der Kyverno-CLI
   (`kyverno apply <policy> --resource <manifest>`) gegen `disallow-latest-tag`.
4. Pipeline: `clone` → (`trivy-scan` ∥ `sbom` ∥ `kyverno-test`).
5. Bonus: Erzwinge zur Laufzeit, dass Images signiert sind (Kyverno `verifyImages`, Cosign).

---

✅ Prüfen: `./05-security-policy/verify.sh`
📖 Lösungen: [`solutions/`](solutions/)
