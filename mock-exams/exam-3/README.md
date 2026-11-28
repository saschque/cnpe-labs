# CNPE Mock Exam 3 – 120 minutes

**Focus:** service mesh, progressive delivery, troubleshooting. Target: ≥ 66 points.
A fresh cluster is recommended; needs ≥ 16 GB RAM.

Preparation (before starting the timer):
```bash
./setup/create-cluster.sh
./setup/install.sh argocd flux argo_workflows tekton crossplane kyverno gatekeeper prometheus istio flagger
./mock-exams/exam-3/setup.sh
```

---

### Task 1 – Egress NetworkPolicy (5 points) · Domain 1

📖 Docs: [Network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

Pods with `app=web` in namespace `m3-app` may send outgoing traffic **only** to pods with
`app=postgres` in namespace `m3-db` (TCP 5432) and to CoreDNS (53 UDP/TCP). Name: `web-egress`.

### Task 2 – StatefulSet (5 points) · Domain 1

📖 Docs: [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) · [Headless services](https://kubernetes.io/docs/concepts/services-networking/service/)

In namespace `m3-db`: headless service `cache` (port 6379) and StatefulSet `cache`
(2 replicas, `redis:7`) with one 128Mi volume each (StorageClass `standard`) at `/data`.

### Task 3 – HPA with behavior (5 points) · Domain 1

📖 Docs: [HPA](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)

HPA `web` for `m3-app/web`: 2–6 replicas, CPU 50 %. Scale-up: at most 2 pods per 30 s.
Scale-down: stabilization window 300 s.

### Task 4 – Argo CD ignoreDifferences (5 points) · Domain 2

📖 Docs: [Diffing customization](https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/)

Application `m3-guestbook` (repo `argocd-example-apps`, path `guestbook`, namespace `m3-gb`,
auto-sync with selfHeal, create the namespace). Argo CD should ignore changes to `spec.replicas`
of Deployments (e.g. made by an HPA) and **not** overwrite them during a sync.

### Task 5 – Fix Flux (5 points) · Domain 2

📖 Docs: [GitRepository](https://fluxcd.io/flux/components/source/gitrepositories/) · [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations/) · [Flux troubleshooting](https://fluxcd.io/flux/cheatsheets/troubleshooting/)

The Flux resources `GitRepository/m3-podinfo` and `Kustomization/m3-podinfo` (both in
`flux-system`) are not `Ready`. Fix them until podinfo runs in namespace `m3-flux`.

### Task 6 – Tekton results (5 points) · Domain 2

📖 Docs: [Tekton tasks](https://tekton.dev/docs/pipelines/tasks/) · [Tekton pipelines](https://tekton.dev/docs/pipelines/pipelines/)

In `ci`: task `m3-version` (parameter `build-number`) writes `v1.0.<build-number>` into the
result `tag`. Task `m3-publish` prints `publishing app:<tag>`. Pipeline `m3-build` connects both
and exposes `tag` as the **pipeline result** `tag`. Start a run with `build-number=42`.

### Task 7 – Argo Workflows: retry & exit handler (5 points) · Domain 2

📖 Docs: [Retries](https://argo-workflows.readthedocs.io/en/latest/retries/) · [Exit handlers](https://argo-workflows.readthedocs.io/en/latest/walk-through/exit-handlers/)

WorkflowTemplate `m3-deploy` in `argo`: step `deploy` (prints `deploying`) with a
`retryStrategy` (limit 2), exit handler `notify` that prints `status: {{workflow.status}}`.
Run it once successfully.

### Task 8 – Flagger canary (5 points) · Domain 2

📖 Docs: [Istio canary tutorial](https://docs.flagger.app/tutorials/istio-progressive-delivery) · [How it works](https://docs.flagger.app/usage/how-it-works)

The Deployment `podinfo` runs in namespace `m3-canary` (sidecar injection enabled). Create a
Canary `podinfo` (port 9898): interval 20s, threshold 3, maxWeight 30, stepWeight 10,
metric `request-success-rate` ≥ 99. The canary must be initialized.

### Task 9 – CRD with two versions (6 points) · Domain 3

📖 Docs: [CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) · [CRD versioning](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/)

Cluster-scoped CRD `tenants.platform.m3.io` (kind `Tenant`) with versions `v1alpha1`
(served, deprecated) and `v1` (served, storage), both with the same schema: `spec.team`
(required), `spec.cpuQuota` (integer, 1–64), status subresource with `status.phase`. Create the
tenant `red` (team `red`, cpuQuota 8) and set its status to `phase: Active`.

### Task 10 – A Crossplane API from scratch (10 points) · Domain 3

📖 Docs: [XRDs](https://docs.crossplane.io/latest/composition/composite-resource-definitions/) · [Compositions](https://docs.crossplane.io/latest/composition/compositions/) · [Patch & transform](https://docs.crossplane.io/latest/guides/function-patch-and-transform/)

The function `function-patch-and-transform` and RBAC for Deployments/Services exist.
Create:
- XRD `webservices.platform.m3.io` (kind `WebService`, namespaced): `spec.image` (required),
  `spec.replicas` (default 1); `status.readyReplicas`.
- Composition `webservice` that creates a Deployment + Service (port 80) and writes the
  Deployment's `status.readyReplicas` back into the XR.
- WebService `shop` (namespace `m3-app`, `nginx:1.27`, 2 replicas) – must be `Ready`.

### Task 11 – Kyverno generate (5 points) · Domain 3

📖 Docs: [Kyverno generate](https://kyverno.io/docs/policy-types/cluster-policy/generate/)

New namespaces with the label `m3-tenant=true` automatically get a NetworkPolicy
`default-deny-ingress` and a LimitRange `defaults` (default request `100m`/`128Mi`).

### Task 12 – Self-service workflow (4 points) · Domain 3

📖 Docs: [Kubernetes resources](https://argo-workflows.readthedocs.io/en/latest/walk-through/kubernetes-resources/) · [Parameters](https://argo-workflows.readthedocs.io/en/latest/walk-through/parameters/) · [Service accounts](https://argo-workflows.readthedocs.io/en/latest/service-accounts/)

WorkflowTemplate `m3-new-service` in `argo` (ServiceAccount `m3-provisioner`, already exists)
with the parameter `name`: creates a WebService `<name>` (image `nginx:1.27`) in namespace
`m3-app`. Run it with `name=orders`.

### Task 13 – Fix a ServiceMonitor (6 points) · Domain 4

📖 Docs: [Prometheus Operator getting started](https://prometheus-operator.dev/docs/developer/getting-started/) · [API reference](https://prometheus-operator.dev/docs/api-reference/api/)

Prometheus does not scrape podinfo in namespace `m3-mon`, although the ServiceMonitor `podinfo`
exists. Fix it (two errors) without renaming the service.

### Task 14 – Alert & query (6 points) · Domain 4

📖 Docs: [Alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) · [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) · [Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)

1. PrometheusRule `m3-rules` (namespace `monitoring`), alert `M3NodeMemoryHigh` (warning):
   node memory utilization > 90 % for 5 min (node-exporter metrics).
2. Write a query for the **top 3 pods by CPU** in `m3-app` to `/tmp/m3-query.txt`.

### Task 15 – Incident (8 points) · Domain 4

📖 Docs: [Debug pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) · [Debug services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

In namespace `m3-incident`, `worker` and `frontend` are not running. Fix both in a targeted way
and write the root causes (one line each) to `/tmp/m3-incident.txt`.

### Task 16 – Istio mTLS & AuthorizationPolicy (8 points) · Domain 5

📖 Docs: [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) · [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/) · [HTTP authorization](https://istio.io/latest/docs/tasks/security/authorization/authz-http/)

In namespace `m3-mesh`, `httpbin` and `sleep` run (with sidecars); in `m3-outside`, a `sleep`
without a sidecar.
- Enforce **STRICT** mTLS in `m3-mesh`.
- `httpbin` only accepts `GET` requests from the ServiceAccount `m3-mesh/sleep`.

### Task 17 – Gatekeeper: allowed registries (7 points) · Domain 5

📖 Docs: [Gatekeeper how-to](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/) · [Enforcement actions](https://open-policy-agent.github.io/gatekeeper/website/docs/violations/)

Create a ConstraintTemplate `K8sAllowedRepos` and a constraint `m3-registries` (`deny`) that,
in namespace `m3-restricted`, only allows pod images from `registry.k8s.io/` and `ghcr.io/`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-3/verify.sh`
