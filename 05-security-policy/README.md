# Domain 5 – Security and Policy Enforcement (15 %)

Competencies from the curriculum:
- Configuring secure service-to-service communication
- Applying RBAC and security controls across platform resources
- Generating audit trails and enforcing policy compliance (SBOM, compliance reports, etc.)
- Using policy engines and admission controllers for governance
- Integrating security scanning and compliance checks into deployment pipelines

Tools needed: `./setup/install.sh istio kyverno gatekeeper tekton`
(Running Kyverno and Gatekeeper side by side works, but it's better to practice them one after the other.)

---

## Task 5.1 – mTLS with Istio ⏱ 8 min

📖 Docs: [mTLS migration](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/) · [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)

1. Create the namespaces `shop` (with sidecar injection) and `legacy` (without).
2. In both namespaces, deploy `httpbin` (image `kennethreitz/httpbin`, port 80, service
   `httpbin`) and a `curl` client (Deployment `sleep`, image `curlimages/curl`, command
   `sleep infinity`).
3. Enforce **STRICT** mTLS in namespace `shop` (`PeerAuthentication` `default`).
4. Show: `legacy/sleep → shop/httpbin` fails, `shop/sleep → shop/httpbin` works.

---

## Task 5.2 – Istio AuthorizationPolicy ⏱ 7 min

📖 Docs: [HTTP authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-http/) · [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)

In namespace `shop`:
1. Create an `AuthorizationPolicy` `deny-all` (empty spec) – nothing works anymore.
2. Create an `AuthorizationPolicy` `allow-sleep-get` that, for `app=httpbin`, only allows
   `GET` requests to `/get` and `/headers` from the ServiceAccount `shop/sleep`.
3. Test: `GET /get` → 200, `POST /post` → 403.

---

## Task 5.3 – Linkerd (alternative) ⏱ 6 min

📖 Docs: [Restricting access](https://linkerd.io/docs/tasks/restricting-access/) · [Automatic mTLS](https://linkerd.io/docs/features/automatic-mtls/) · [Authorization policy](https://linkerd.io/docs/reference/authorization-policy/)

In case the exam uses Linkerd instead of Istio:
1. Inject Linkerd into the namespace `mesh-demo` (annotation).
2. Check with `linkerd viz edges` / `linkerd diagnostics` or `linkerd check --proxy` that mTLS is active.
3. Create a `Server` + `AuthorizationPolicy` + `MeshTLSAuthentication` that only allows clients
   with the ServiceAccount `frontend` to access port 80 of `backend`.

---

## Task 5.4 – RBAC & ServiceAccounts ⏱ 6 min

📖 Docs: [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) · [Service accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) · [kubectl create token](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/)

1. Create the ServiceAccount `deployer` in namespace `ci`.
2. In the namespaces `gb-dev` and `gb-staging`, it may `get/list/patch/update` Deployments but
   **not** delete them. Use **one** ClusterRole `deployment-updater` and two RoleBindings.
3. It may read namespaces cluster-wide.
4. Disable automatic token mounting for the ServiceAccount.
5. Check everything with `kubectl auth can-i --as=system:serviceaccount:ci:deployer`.
6. Create a time-limited token (10 min) for the ServiceAccount.

---

## Task 5.5 – Pod Security Admission ⏱ 4 min

📖 Docs: [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) · [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) · [Namespace labels](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/)

1. Create the namespace `secure-apps` and set PSA labels: `enforce=baseline`, `warn=restricted`,
   `audit=restricted` (each with version `latest`).
2. Try to create a privileged pod – it must be rejected.
3. Write a pod manifest that complies with **restricted**.

---

## Task 5.6 – Kyverno policies ⏱ 12 min

📖 Docs: [Validate](https://kyverno.io/docs/policy-types/cluster-policy/validate/) · [Mutate](https://kyverno.io/docs/policy-types/cluster-policy/mutate/) · [Policy reports](https://kyverno.io/docs/guides/reports/) · [Exceptions](https://kyverno.io/docs/guides/exceptions/)

Create the following `ClusterPolicy`s:
1. `require-team-label` (**Enforce**): Deployments must have the label `team`.
   Exception: namespaces `kube-system`, `argocd`, `flux-system`.
2. `disallow-latest-tag` (**Enforce**): container images must have a tag and must not be
   `:latest`.
3. `add-default-resources` (**Mutate**): adds `cpu: 100m`, `memory: 128Mi` to containers
   without `resources.requests`.
4. `require-probes` (**Audit**): Deployments should have a `readinessProbe`.
5. Show the violations of 4. as a `PolicyReport` (`kubectl get policyreport -A`).
6. Create a `PolicyException` for the Deployment `legacy-app` in namespace `legacy`
   for `require-team-label`.

---

## Task 5.7 – OPA Gatekeeper ⏱ 10 min

📖 Docs: [Gatekeeper how-to](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/) · [Audit](https://open-policy-agent.github.io/gatekeeper/website/docs/audit/) · [Enforcement actions](https://open-policy-agent.github.io/gatekeeper/website/docs/violations/)

1. Create a `ConstraintTemplate` `K8sRequiredLabels` (Rego) that checks whether certain labels
   are present (parameter: list `labels`).
2. Create a constraint `ns-must-have-owner` that requires the label `owner` on **namespaces** –
   initially with `enforcementAction: dryrun`.
3. Read the audit results (`status.violations`) of the constraint.
4. Switch to `deny` and test.
5. Bonus: create a `ConstraintTemplate` `K8sAllowedRepos` that only allows images from
   `ghcr.io/` and `registry.k8s.io/`.

---

## Task 5.8 – Audit trail ⏱ 5 min

📖 Docs: [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

The kind cluster writes an API audit log (see `setup/audit-policy.yaml`).
1. Delete a Deployment and find the audit entry: who deleted what, and when?
2. Find all changes to RoleBindings in the last hour.
3. Explain the audit levels `None`, `Metadata`, `Request`, `RequestResponse`.
   Why are secrets only logged at `Metadata`?

---

## Task 5.9 – Security scanning in the pipeline ⏱ 12 min

📖 Docs: [Trivy](https://trivy.dev/docs/latest/guide/) · [Syft](https://github.com/anchore/syft) · [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/reference/kyverno/) · [Tekton pipelines](https://tekton.dev/docs/pipelines/pipelines/) · [Verify images](https://kyverno.io/docs/policy-types/cluster-policy/verify-images/overview/)

Extend the Tekton pipeline from 2.7 (namespace `ci`) with:
1. Task `trivy-scan`: scans an image (parameter `image`) with `aquasec/trivy` and **fails**
   when `CRITICAL` vulnerabilities are found.
2. Task `sbom`: uses `anchore/syft` to create an SBOM in **SPDX-JSON** format and stores it in
   the workspace under `sbom/`.
3. Task `kyverno-test`: checks the manifests in the repo with the Kyverno CLI
   (`kyverno apply <policy> --resource <manifest>`) against `disallow-latest-tag`.
4. Pipeline: `clone` → (`trivy-scan` ∥ `sbom` ∥ `kyverno-test`).
5. Bonus: enforce at runtime that images are signed (Kyverno `verifyImages`, Cosign).

---

# More exercises

## Task 5.10 – Egress control with Istio ⏱ 8 min

📖 Docs: [Egress control](https://istio.io/latest/docs/tasks/traffic-management/egress/egress-control/) · [Sidecar](https://istio.io/latest/docs/reference/config/networking/sidecar/) · [ServiceEntry](https://istio.io/latest/docs/reference/config/networking/service-entry/)

Pods in namespace `shop` should only reach known external destinations.
1. Create a `Sidecar` resource `default` in namespace `shop` with
   `outboundTrafficPolicy.mode: REGISTRY_ONLY` (only destinations from the service registry allowed).
2. Allow access to `httpbin.org` (HTTP, port 80) with a `ServiceEntry` `httpbin-org`.
3. Test from `shop/sleep`: `http://httpbin.org/get` → 200, `http://example.com` → 502.

---

## Task 5.11 – Pod Security Standards with Kyverno ⏱ 6 min

📖 Docs: [Kyverno validate (podSecurity)](https://kyverno.io/docs/policy-types/cluster-policy/validate/) · [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

PSA is coarse-grained per namespace. Implement the standards with Kyverno in a more granular way:
1. `ClusterPolicy` `pss-restricted` (Enforce): pods in namespaces with the label
   `security=strict` must comply with the Pod Security Standard **restricted**
   (Kyverno `podSecurity` subrule).
2. Exception in the same rule: images `ghcr.io/my-org/legacy-*` may violate the control
   "Running as Non-root".
3. Test with a namespace `strict-apps` (label `security=strict`) and an nginx pod.

---

## Task 5.12 – Gatekeeper mutation & `gator` ⏱ 8 min

📖 Docs: [Mutation](https://open-policy-agent.github.io/gatekeeper/website/docs/mutation/) · [gator CLI](https://open-policy-agent.github.io/gatekeeper/website/docs/gator/)

1. Create a Gatekeeper `Assign` mutation `always-pull` that sets `imagePullPolicy: Always` for
   every container in all pods in namespace `shop`.
2. Create an `AssignMetadata` mutation `owner-label` that adds the label `owner: platform` to
   every pod in namespace `shop` (if not already present).
3. Test the `K8sRequiredLabels` constraint from 5.7 **offline** with the `gator` CLI
   (`gator test` or a `gator verify` suite).

---

## Task 5.13 – RBAC audit ⏱ 8 min

📖 Docs: [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) · [kubectl auth can-i](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/)

```bash
kubectl apply -f 05-security-policy/solutions/5.13-setup.yaml
```
1. List all subjects (users, groups, ServiceAccounts) that have the ClusterRole `cluster-admin`
   through a `ClusterRoleBinding` → `/tmp/cluster-admins.txt`.
2. Find all ServiceAccounts in the namespaces `ci` and `default` that can read secrets
   cluster-wide → `/tmp/secret-readers.txt`.
3. Remove the over-privileged binding of the ServiceAccount `ci/legacy-bot` and give it only
   `view` in namespace `ci` instead.

---

✅ Check: `./05-security-policy/verify.sh`
📖 Solutions: [`solutions/`](solutions/)
