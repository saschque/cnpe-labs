# Domain 3 – Platform APIs and Self-Service Capabilities (25 %)

Competencies from the curriculum:
- Designing and creating Custom Resource Definitions (CRDs) for platform services
- Implementing workflows for self-service provisioning using platform APIs
- Using Kubernetes operators for platform automation and integration
- Using automation frameworks for self-service provisioning

Tools needed: `./setup/install.sh crossplane kyverno argo_workflows`

> **Crossplane mental model:** XRD = schema (the API) · XR = instance (the request) ·
> Composition = recipe (what gets built from it) · Function = logic inside the recipe.
> The solutions use **Crossplane v2** (namespaced XRs, no claims). For v1, see the notes in the
> solutions – in the exam, check with `kubectl get crd | grep crossplane` and `helm list -A`
> which version is running.

---

## Task 3.1 – Design a CRD ⏱ 10 min

Create a CRD for the platform API `databases.platform.example.org`:
- Kind `Database`, plural `databases`, short name `db`, category `platform`, **namespaced**
- Version `v1alpha1` (served, storage)
- `spec`:
  - `engine` – required, enum `postgres` | `mysql`
  - `version` – string, required
  - `storageGB` – integer, 1–100, default 10
  - `highAvailability` – boolean, default `false`
- `status` subresource with the field `phase` (string)
- Additional columns in `kubectl get db`: `ENGINE`, `VERSION`, `PHASE`, `AGE`

Test: An object with `engine: oracle` or `storageGB: 500` must be rejected.

---

## Task 3.2 – CEL validation & versioning ⏱ 7 min

Extend the CRD from 3.1:
1. Rule via `x-kubernetes-validations`: if `highAvailability: true`, then `storageGB >= 20` is
   required. Error message: "HA requires at least 20 GB".
2. `engine` must **not be changed** after creation (immutability rule with `oldSelf`).
3. Add a version `v1beta1` (served, **not** storage). Mark `v1alpha1` as `deprecated` with a warning.

---

## Task 3.3 – Crossplane: your own platform API with a Composition ⏱ 15 min

Developers should be able to order a web app with a single object:

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

1. Install the function `function-patch-and-transform`.
2. Allow Crossplane to manage Deployments and Services (RBAC, aggregated ClusterRole).
3. Create the XRD `webapps.platform.example.org` (namespaced, fields `image` (required),
   `replicas` (default 1), `port` (default 80); status field `url`).
4. Create a Composition `webapp-basic` (pipeline mode) that creates a **Deployment** and a
   **Service**. `image`, `replicas` and `port` are patched. Write the internal URL
   `http://<name>.<namespace>.svc` to `status.url`.
5. Create the WebApp `shop` and check with `crossplane beta trace webapp shop -n team-a`.

---

## Task 3.4 – Crossplane troubleshooting ⏱ 7 min

```bash
kubectl apply -f 03-platform-apis/solutions/3.4-broken-webapp.yaml
```
The WebApp `broken` does not become `Ready`. Find the cause(s). Useful commands:
`kubectl describe webapp`, `crossplane beta trace`, `kubectl get composition`,
`kubectl -n crossplane-system logs deploy/crossplane`, `kubectl get functions`.

---

## Task 3.5 – Working with operators ⏱ 6 min

Crossplane, Argo CD, Flux, Kyverno … are all operators. Answer using `kubectl`:
1. Which CRDs does Argo CD ship? (`kubectl api-resources --api-group=argoproj.io`)
2. Which controller reconciles `Application` objects, and which ServiceAccount does it run as?
3. Which cluster-wide permissions does this ServiceAccount have? (`kubectl auth can-i --list --as=...`)
4. Use `kubectl explain application.spec.syncPolicy --recursive` and
   `kubectl explain webapp.spec` to find a CRD's fields without docs.
5. Set the Argo CD application controller to log level `debug` without using Helm
   (tip: ConfigMap `argocd-cmd-params-cm`).

---

## Task 3.6 – Self-service namespaces with Kyverno `generate` ⏱ 8 min

When a developer creates a namespace with the labels `platform.example.org/tenant=true` and
`team=<name>`, the platform should **automatically** create:
- a `ResourceQuota` `tenant-quota` (requests.cpu 2, requests.memory 4Gi)
- a `NetworkPolicy` `default-deny` (ingress)
- a `RoleBinding` `team-edit` that gives the group `<team>-devs` the ClusterRole `edit`

The generated resources should be kept in sync (`synchronize: true`).

---

## Task 3.7 – Self-service workflow with Argo Workflows ⏱ 10 min

Create a `WorkflowTemplate` `provision-tenant` in namespace `argo` with the parameters `team` and
`cpu`. The workflow should:
1. Create the namespace `tenant-<team>` with the labels from 3.6 (resource template, `action: create`)
2. Wait until the ResourceQuota exists (Kyverno generated it)
3. Create the WebApp `welcome` (from 3.3) in the new namespace

The workflow's ServiceAccount needs the right permissions for this – create them.

---

## Task 3.8 – RBAC for the platform API ⏱ 5 min

Developers in the group `team-a-devs` should, in namespace `team-a`,
- be allowed to **create, update, delete and read** `webapps`,
- only be allowed to **read** `deployments` and `services`.

Create the `Role` `webapp-author` and a `RoleBinding`, and check both cases with `kubectl auth can-i`.

---

# More exercises

## Task 3.9 – Size profiles via map transform & composition selector ⏱ 12 min

Instead of replicas, developers should only specify a **size**.
1. Extend the XRD `webapps.platform.example.org` with the optional field `spec.size`
   (enum `small` | `medium` | `large`, default `small`) and the status field
   `status.availableReplicas` (integer).
2. Create a second Composition `webapp-sized` with the label `profile: sized` that
   - translates `size` into replicas via a **map transform**: small→1, medium→2, large→4,
   - also translates `size` into a memory request: small→`128Mi`, medium→`256Mi`, large→`512Mi`,
   - otherwise creates a Deployment and a Service like `webapp-basic`.
3. Create the WebApp `catalog` (namespace `team-a`, image `nginx:1.27`, `size: medium`) that
   selects the Composition **via the label selector** (not by name).

---

## Task 3.10 – Reporting status back ⏱ 5 min

Extend `webapp-sized` so that the Deployment's `status.availableReplicas` ends up in the WebApp's
`status.availableReplicas` (`ToCompositeFieldPath`). Add a printer column `READY` for it to the
XRD. Check with `kubectl -n team-a get webapp catalog`.

---

## Task 3.11 – Guardrails for the platform API ⏱ 7 min

Create a Kyverno `ClusterPolicy` `webapp-guardrails` (Enforce) for `WebApp` objects:
1. In namespaces with the label `env=dev`, at most `replicas: 2` and only `size: small` or
   `medium` are allowed.
2. Everywhere: `spec.image` must not end with `:latest`.

Test with `kubectl apply --dry-run=server`.

---

## Task 3.12 – Package lifecycle of an operator ⏱ 8 min

Crossplane packages (providers, functions, configurations) are rolled out through revisions.
1. List the `FunctionRevision`s of `function-patch-and-transform`. Which one is active?
2. Set `revisionActivationPolicy: Manual` on the function.
3. Change the package version to a **different** available version. Check that a new,
   **inactive** revision appears and the old one stays active.
4. Activate the new revision manually. How would you roll back?

---

✅ Check: `./03-platform-apis/verify.sh`
📖 Solutions: [`solutions/`](solutions/)
