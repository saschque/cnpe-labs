# CNPE Mock Exam 2 – 120 minutes

**Rules:** 120-minute timer. Only the official docs. No reference solutions. Target: ≥ 66 points.
Best on a **fresh cluster** (`kind delete cluster --name cnpe` → create it again).

Preparation (before starting the timer):
```bash
./setup/create-cluster.sh
./setup/install.sh argocd flux argo_workflows tekton crossplane kyverno prometheus jaeger_otel
./mock-exams/exam-2/setup.sh
```
> Needs the full cluster with worker nodes (task 1 uses `cnpe-worker`) – not `--lite`.

---

### Task 1 – Dedicated batch pool (5 points) · Domain 1
The node `cnpe-worker` is labeled `pool=batch` and tainted with `workload=batch:NoSchedule`.
In namespace `m2-batch`, create a Deployment `cruncher` (image `registry.k8s.io/pause:3.10`,
2 replicas) whose pods run **exclusively** on this pool.

### Task 2 – Priority & disruption budget (5 points) · Domain 1
Create a PriorityClass `m2-high` (value `100000`). The Deployment `m2-shop/web` should use it.
Create a PDB `web-pdb` that, during voluntary disruptions, makes at most **1** `web` pod
unavailable at a time.

### Task 3 – Resource guardrails (5 points) · Domain 1
In namespace `m2-shop`:
- LimitRange `m2-ratio`: for containers, the memory limit may be at most **2×** the memory request.
- ResourceQuota `m2-no-besteffort`: no BestEffort pods.

### Task 4 – ApplicationSet (5 points) · Domain 2
Create an ApplicationSet `m2-dirs` with a **Git directory generator** over
`https://github.com/argoproj/argocd-example-apps` that creates one Application `m2-<directory>`
for exactly the directories `helm-guestbook` and `kustomize-guestbook`.
Destination namespace `m2-<directory>`, created automatically, auto-sync.

### Task 5 – AppProject (5 points) · Domain 2
Create an AppProject `m2-team` that only allows the repo `argocd-example-apps` and only the
destination namespaces `m2-team-*` (in-cluster). Create the Application `m2-gb` in it (path
`guestbook`, namespace `m2-team-gb`, auto-sync, creating the namespace allowed).

### Task 6 – Flux with a patch (5 points) · Domain 2
A `GitRepository` `m2-podinfo` exists in `flux-system`. Create a Kustomization `m2-podinfo` that
deploys `./kustomize` into the namespace `m2-flux` and sets the HPA `podinfo` to
`minReplicas: 3` via a patch.

### Task 7 – Tekton when/finally (5 points) · Domain 2
In `ci`, create a pipeline `m2-release` with the parameter `run-tests` (default `"true"`):
task `build` → task `test` (only if `run-tests` = `"true"`) → task `package`; plus a `finally`
task `cleanup`. All tasks just print their name. Start a successful run with `run-tests=false`.

### Task 8 – Argo Workflows fan-out (5 points) · Domain 2
In `argo`, create a WorkflowTemplate `m2-fanout`: a step `process` runs **in parallel** for the
items `eu`, `us`, `asia` (`withItems`) and prints `processing <item>`. Afterwards a step
`summary` prints `done`. Run it once successfully.

### Task 9 – CRD with CEL (7 points) · Domain 3
Create the **cluster-scoped** CRD `environments.platform.m2.io` (kind `Environment`, version
`v1`): `spec.tier` (required, enum `dev`|`prod`), `spec.owner` (required), `spec.approvedBy`
(optional). CEL rule: with `tier: prod`, `approvedBy` must be set. Then create the environment
`checkout-prod` (tier prod, owner `team-red`, approvedBy `cto`).

### Task 10 – Crossplane map transform (9 points) · Domain 3
`setup.sh` installed the XRD `caches.cache.m2.io` (kind `Cache`, field `spec.size`: `small`|`large`).
Create a Composition `cache-cm` that creates one **ConfigMap** per cache, named after the cache:
`data.engine: redis` (fixed) and `data.memory`: small→`256Mi`, large→`1Gi`.
Create the cache `sessions` (`size: large`) in namespace `m2-shop`. It must become `Ready`.

### Task 11 – RBAC for the platform API (4 points) · Domain 3
The group `m2-devs` may create, read and delete caches in namespace `m2-shop`, but only read
ConfigMaps.

### Task 12 – Guardrail (5 points) · Domain 3
Create a Kyverno ClusterPolicy `m2-no-large-in-dev` (Enforce): caches with `size: large` are
rejected in namespaces with the label `env=dev` (`m2-dev` already exists).

### Task 13 – Incident (7 points) · Domain 4
The Deployment `m2-incident/api` does not work (two errors). Fix it until 2 pods are `Ready`
and **no** new restarts happen.

### Task 14 – SLO alert (6 points) · Domain 4
Create a PrometheusRule `m2-slo` (namespace `monitoring`) with
- recording rule `sli:m2_api_errors:ratio_rate5m` = share of 5xx among all `http_requests_total`
  in namespace `m2-shop` (5m window),
- recording rule `sli:m2_api_errors:ratio_rate1h` (1h window),
- alert `M2ErrorBudgetBurn` (critical) when both rates are > 14.4 × 0.001.

### Task 15 – Fix the OTel Collector (7 points) · Domain 4
The collector `m2-otel/otel-collector` does not start, and clients can't reach it through the
service. Fix both. Spans should go via OTLP to `jaeger.observability:4317` (without TLS) **and**
to the `debug` exporter.

### Task 16 – Pod security with Kyverno (8 points) · Domain 5
Create a ClusterPolicy `m2-restricted` (Enforce) that enforces the Pod Security Standard
**restricted** for pods in namespace `m2-secure` (`podSecurity` subrule). Then adjust the
Deployment `m2-secure/app` so its pods can still be created (successful rollout).

### Task 17 – RBAC audit (7 points) · Domain 5
Write all ServiceAccounts that have `cluster-admin` via a ClusterRoleBinding to
`/tmp/m2-admins.txt` (format `namespace/name`). Remove the cluster-admin binding of
`m2-shop/old-ci` and give it `edit` **only** in namespace `m2-shop` instead.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-2/verify.sh`
Clean up: `kubectl taint node cnpe-worker workload-` and `kubectl label node cnpe-worker pool-`
