# CNPE Mock Exam 1 – 120 minutes

**Rules:** Set a 120-minute timer. Only use the official docs (kubernetes.io, argo-cd.readthedocs.io,
fluxcd.io, crossplane.io, kyverno.io, open-policy-agent.github.io, istio.io, linkerd.io,
prometheus.io, opentelemetry.io, tekton.dev, argoproj.github.io, docs.flagger.app, opencost.io).
No reference solutions. Your pass mark: **66 out of 100 points**.

Preparation (before starting the timer):
```bash
./setup/create-cluster.sh
./setup/install.sh argocd flux argo_workflows tekton crossplane kyverno prometheus
./mock-exams/exam-1/setup.sh
```

Tip: Read all tasks first, take the quick wins, flag hard tasks.

---

### Task 1 – Tenant quota (4 points) · Domain 1
The namespace `mx-team-red` exists. Create a ResourceQuota `red-quota` with `requests.cpu: 3`,
`requests.memory: 6Gi`, `pods: 15` and a LimitRange `red-defaults` with default requests
`50m`/`64Mi` and default limits `250m`/`256Mi`.

### Task 2 – HPA (4 points) · Domain 1
Create an HPA for the Deployment `mx-team-red/api`: 3–12 replicas, CPU 70 %, memory 80 %.

### Task 3 – NetworkPolicy (5 points) · Domain 1
In namespace `mx-team-red`, pods with `app=db` may only receive traffic on port 5432 from pods
with `app=api` in the same namespace. All other ingress to `app=db` is forbidden.

### Task 4 – Argo CD Application (6 points) · Domain 2
Create the Application `mx-kustomize` (project `default`) that deploys
`https://github.com/argoproj/argocd-example-apps` path `kustomize-guestbook` into the namespace
`mx-gb`. Auto-sync with prune, create the namespace automatically, and set the `namePrefix` to
`mx-` using the Application's Kustomize option.

### Task 5 – Argo CD troubleshooting (6 points) · Domain 2
The Application `mx-broken` (created by `setup.sh`) is not `Synced/Healthy`. Fix it without
deleting the Application.

### Task 6 – Flux (6 points) · Domain 2
Use Flux to deploy the Helm chart `podinfo` (OCI `oci://ghcr.io/stefanprodan/charts`) as the
HelmRelease `mx-podinfo` into the namespace `mx-flux` with `replicaCount: 3`. The reconciliation
should run every 2 minutes.

### Task 7 – Argo Workflows (6 points) · Domain 2
In namespace `argo`, create a WorkflowTemplate `mx-pipeline` with the parameter `env` (default
`dev`) and the steps `test` → `deploy` (sequential, `steps` syntax), each printing
`echo <step> to <env>`. Run it once with `env=staging`; the workflow must be `Succeeded`.

### Task 8 – Tekton (7 points) · Domain 2
In namespace `ci`, create a task `mx-hello` with the parameter `name` that writes `Hello <name>`
into a **result** `greeting`, and a pipeline `mx-greet` that runs `mx-hello` and passes the result
to a second task `mx-print` (prints the result). Start a successful PipelineRun.

### Task 9 – CRD (7 points) · Domain 3
Create the CRD `queues.messaging.example.org` (kind `Queue`, namespaced, short name `q`,
version `v1`) with `spec.maxMessages` (integer, required, 1–10000), `spec.fifo` (boolean,
default `false`) and a printer column `MAX`. Then create the queue `orders` in namespace
`mx-team-red` with `maxMessages: 500`.

### Task 10 – Crossplane (9 points) · Domain 3
`setup.sh` installed an XRD `buckets.storage.example.org` (kind `Bucket`). Create a Composition
`bucket-configmap` that creates a **ConfigMap** named after the bucket for every `Bucket`, whose
`data.size` contains the value of `spec.sizeGB` (as a string!).
Then create the bucket `logs` (`sizeGB: 50`) in namespace `mx-team-red` – it must become `Ready`.
*Note: the function `function-patch-and-transform` and RBAC for ConfigMaps already exist.*

### Task 11 – Self-service with Kyverno (6 points) · Domain 3
Every new namespace with the label `mx-tenant=true` should automatically get a ConfigMap
`platform-info` with `data.contact: platform@example.org` (kept in sync).

### Task 12 – PrometheusRule (6 points) · Domain 4
Create a PrometheusRule `mx-rules` in namespace `monitoring` with the alert
`DeploymentReplicasMismatch` (severity `warning`) that fires when
`kube_deployment_spec_replicas` ≠ `kube_deployment_status_replicas_available` for 10 minutes.

### Task 13 – Incident (7 points) · Domain 4
In namespace `mx-incident`, the app `checkout` is not working correctly (two errors). Fix it
until all pods are `Ready` and the service `checkout` has endpoints. Write the two root causes
(one line each) to `/tmp/mx-incident.txt`.

### Task 14 – Metric query (4 points) · Domain 4
Write a PromQL query to `/tmp/mx-query.txt` that returns the 3 namespaces with the highest
memory working set.

### Task 15 – RBAC (5 points) · Domain 5
ServiceAccount `mx-auditor` in namespace `mx-team-red`: may **read** (get/list/watch) pods,
Deployments and events cluster-wide, but not secrets. Create the required objects.

### Task 16 – Kyverno policy (6 points) · Domain 5
Create a ClusterPolicy `mx-require-limits` (Enforce) that rejects pods in namespace
`mx-team-red` when a container has no memory limit.

### Task 17 – Pod Security Admission (6 points) · Domain 5
Set Pod Security Admission `enforce=restricted` for the namespace `mx-team-red`.
Make sure the Deployment `mx-team-red/api` can still create new pods afterwards
(adjust its pod template). *Watch out: check that it still works with task 16.*

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-1/verify.sh`
