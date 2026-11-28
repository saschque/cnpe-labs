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

📖 Docs: [Resource quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) · [Limit ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)

The namespace `mx-team-red` exists. Create a ResourceQuota `red-quota` with `requests.cpu: 3`,
`requests.memory: 6Gi`, `pods: 15` and a LimitRange `red-defaults` with default requests
`50m`/`64Mi` and default limits `250m`/`256Mi`.

### Task 2 – HPA (4 points) · Domain 1

📖 Docs: [HPA](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)

Create an HPA for the Deployment `mx-team-red/api`: 3–12 replicas, CPU 70 %, memory 80 %.

### Task 3 – NetworkPolicy (5 points) · Domain 1

📖 Docs: [Network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

In namespace `mx-team-red`, pods with `app=db` may only receive traffic on port 5432 from pods
with `app=api` in the same namespace. All other ingress to `app=db` is forbidden.

### Task 4 – Argo CD Application (6 points) · Domain 2

📖 Docs: [Application spec](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/) · [Automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/) · [Sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)

Create the Application `mx-kustomize` (project `default`) that deploys
`https://github.com/argoproj/argocd-example-apps` path `kustomize-guestbook` into the namespace
`mx-gb`. Auto-sync with prune, create the namespace automatically, and set the `namePrefix` to
`mx-` using the Application's Kustomize option.

### Task 5 – Argo CD troubleshooting (6 points) · Domain 2

📖 Docs: [Argo CD troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/) · [argocd app get](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_get/)

The Application `mx-broken` (created by `setup.sh`) is not `Synced/Healthy`. Fix it without
deleting the Application.

### Task 6 – Flux (6 points) · Domain 2

📖 Docs: [HelmRepository](https://fluxcd.io/flux/components/source/helmrepositories/) · [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)

Use Flux to deploy the Helm chart `podinfo` (OCI `oci://ghcr.io/stefanprodan/charts`) as the
HelmRelease `mx-podinfo` into the namespace `mx-flux` with `replicaCount: 3`. The reconciliation
should run every 2 minutes.

### Task 7 – Argo Workflows (6 points) · Domain 2

📖 Docs: [WorkflowTemplates](https://argo-workflows.readthedocs.io/en/latest/workflow-templates/) · [Steps](https://argo-workflows.readthedocs.io/en/latest/walk-through/steps/) · [Parameters](https://argo-workflows.readthedocs.io/en/latest/walk-through/parameters/)

In namespace `argo`, create a WorkflowTemplate `mx-pipeline` with the parameter `env` (default
`dev`) and the steps `test` → `deploy` (sequential, `steps` syntax), each printing
`echo <step> to <env>`. Run it once with `env=staging`; the workflow must be `Succeeded`.

### Task 8 – Tekton (7 points) · Domain 2

📖 Docs: [Tekton tasks](https://tekton.dev/docs/pipelines/tasks/) · [Tekton pipelines](https://tekton.dev/docs/pipelines/pipelines/) · [PipelineRuns](https://tekton.dev/docs/pipelines/pipelineruns/)

In namespace `ci`, create a task `mx-hello` with the parameter `name` that writes `Hello <name>`
into a **result** `greeting`, and a pipeline `mx-greet` that runs `mx-hello` and passes the result
to a second task `mx-print` (prints the result). Start a successful PipelineRun.

### Task 9 – CRD (7 points) · Domain 3

📖 Docs: [CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)

Create the CRD `queues.messaging.example.org` (kind `Queue`, namespaced, short name `q`,
version `v1`) with `spec.maxMessages` (integer, required, 1–10000), `spec.fifo` (boolean,
default `false`) and a printer column `MAX`. Then create the queue `orders` in namespace
`mx-team-red` with `maxMessages: 500`.

### Task 10 – Crossplane (9 points) · Domain 3

📖 Docs: [XRDs](https://docs.crossplane.io/latest/composition/composite-resource-definitions/) · [Compositions](https://docs.crossplane.io/latest/composition/compositions/) · [Patch & transform](https://docs.crossplane.io/latest/guides/function-patch-and-transform/)

`setup.sh` installed an XRD `buckets.storage.example.org` (kind `Bucket`). Create a Composition
`bucket-configmap` that creates a **ConfigMap** named after the bucket for every `Bucket`, whose
`data.size` contains the value of `spec.sizeGB` (as a string!).
Then create the bucket `logs` (`sizeGB: 50`) in namespace `mx-team-red` – it must become `Ready`.
*Note: the function `function-patch-and-transform` and RBAC for ConfigMaps already exist.*

### Task 11 – Self-service with Kyverno (6 points) · Domain 3

📖 Docs: [Kyverno generate](https://kyverno.io/docs/policy-types/cluster-policy/generate/)

Every new namespace with the label `mx-tenant=true` should automatically get a ConfigMap
`platform-info` with `data.contact: platform@example.org` (kept in sync).

### Task 12 – PrometheusRule (6 points) · Domain 4

📖 Docs: [Alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) · [Alerting with the Operator](https://prometheus-operator.dev/docs/developer/alerting/)

Create a PrometheusRule `mx-rules` in namespace `monitoring` with the alert
`DeploymentReplicasMismatch` (severity `warning`) that fires when
`kube_deployment_spec_replicas` ≠ `kube_deployment_status_replicas_available` for 10 minutes.

### Task 13 – Incident (7 points) · Domain 4

📖 Docs: [Debug pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) · [Debug services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) · [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

In namespace `mx-incident`, the app `checkout` is not working correctly (two errors). Fix it
until all pods are `Ready` and the service `checkout` has endpoints. Write the two root causes
(one line each) to `/tmp/mx-incident.txt`.

### Task 14 – Metric query (4 points) · Domain 4

📖 Docs: [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) · [Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/) · [Operators](https://prometheus.io/docs/prometheus/latest/querying/operators/)

Write a PromQL query to `/tmp/mx-query.txt` that returns the 3 namespaces with the highest
memory working set.

### Task 15 – RBAC (5 points) · Domain 5

📖 Docs: [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) · [kubectl auth can-i](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/)

ServiceAccount `mx-auditor` in namespace `mx-team-red`: may **read** (get/list/watch) pods,
Deployments and events cluster-wide, but not secrets. Create the required objects.

### Task 16 – Kyverno policy (6 points) · Domain 5

📖 Docs: [Kyverno validate](https://kyverno.io/docs/policy-types/cluster-policy/validate/)

Create a ClusterPolicy `mx-require-limits` (Enforce) that rejects pods in namespace
`mx-team-red` when a container has no memory limit.

### Task 17 – Pod Security Admission (6 points) · Domain 5

📖 Docs: [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) · [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

Set Pod Security Admission `enforce=restricted` for the namespace `mx-team-red`.
Make sure the Deployment `mx-team-red/api` can still create new pods afterwards
(adjust its pod template). *Watch out: check that it still works with task 16.*

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-1/verify.sh`
