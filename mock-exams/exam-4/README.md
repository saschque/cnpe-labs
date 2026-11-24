# CNPE Mock Exam 4 – 120 minutes

**Focus:** cost, operating operators, troubleshooting platform tools, auditing.
Target: ≥ 66 points. A fresh cluster is recommended (the audit log from `setup/kind-config.yaml` is required).

Preparation (before starting the timer):
```bash
./setup/create-cluster.sh
./setup/install.sh argocd flux argo_workflows tekton crossplane kyverno prometheus opencost
./mock-exams/exam-4/setup.sh
```

---

### Task 1 – Cost per team (5 points) · Domain 1
Use OpenCost to get the cost of the last 24 h **aggregated by the label `team`** →
`/tmp/m4-cost.json`. Write the name of the most expensive team (excluding `__unallocated__`/`__idle__`)
to `/tmp/m4-top-team.txt`.

### Task 2 – Object quotas (5 points) · Domain 1
In namespace `m4-blue`: ResourceQuota `m4-objects` with max. 20 ConfigMaps, 20 Secrets,
5 Services and **0** NodePort Services. LimitRange `m4-pvc`: PVCs at most `5Gi`.

### Task 3 – Anti-affinity (5 points) · Domain 1
Change the Deployment `m4-blue/api` (2 replicas) so that **never** two `api` pods run on the
same node (hard rule).

### Task 4 – App of apps (6 points) · Domain 2
Create the Application `m4-root` (project `default`, destination namespace `argocd`) that deploys
the path `apps` from `https://github.com/argoproj/argocd-example-apps` – a Helm chart that itself
creates Applications. Auto-sync with prune.

### Task 5 – Flux valuesFrom (6 points) · Domain 2
An OCI `HelmRepository` `m4-charts` (`oci://ghcr.io/stefanprodan/charts`) exists in `flux-system`.
In namespace `m4-flux`, create a ConfigMap `m4-podinfo-values` (key `values.yaml`:
`replicaCount: 2`, `ui.message: m4`) and a HelmRelease `m4-podinfo` (chart `podinfo`) that takes
its values **from this ConfigMap**.

### Task 6 – Fix Tekton (7 points) · Domain 2
The PipelineRun `m4-ci-run-1` (namespace `ci`) fails. Fix the pipeline and/or run (three errors)
and start a new, successful run of the pipeline `m4-ci`.

### Task 7 – CronWorkflow (6 points) · Domain 2
The CronWorkflow `m4-report` (namespace `argo`) is suspended. Change the schedule to every
30 minutes (time zone `Europe/Berlin`), resume it and **immediately** trigger one run manually
from the CronWorkflow. The run must succeed.

### Task 8 – CRD from a specification (7 points) · Domain 3
CRD `backups.ops.m4.io` (kind `Backup`, namespaced, short name `bk`, category `ops`, version `v1`):
- `spec.schedule` – required, string
- `spec.retentionDays` – integer 1–90, default 7
- `spec.target.kind` – required, enum `Database`|`Volume`; `spec.target.name` – required
- Printer columns `SCHEDULE`, `RETENTION`, `TARGET` (= `target.name`)

Create `nightly` in namespace `m4-blue` (`0 2 * * *`, target Database `orders`).

### Task 9 – Crossplane troubleshooting (8 points) · Domain 3
The XR `Queue` `jobs` in namespace `m4-blue` does not become `Ready`. Fix the Composition
(two errors) until a ConfigMap `jobs` with `data.retention: "14"` exists.

### Task 10 – Mutation on the platform API (5 points) · Domain 3
Create a Kyverno ClusterPolicy `m4-label-backups` that adds the label
`platform.m4.io/managed: "true"` to every `Backup`.

### Task 11 – Stuck object (5 points) · Domain 3
The object `widget/stuck` in namespace `m4-blue` was deleted but has been `Terminating` forever.
Find the cause and make it go away.

### Task 12 – Dashboard & alert routing (6 points) · Domain 4
1. ConfigMap `m4-dashboard` (namespace `monitoring`) that Grafana loads automatically as the
   dashboard "M4 Overview" (one panel with `sum(kube_pod_status_phase{phase="Running"})`).
2. `AlertmanagerConfig` `m4-routing` (namespace `monitoring`): alerts with `team=blue` go to the
   webhook `http://blue-hook.m4-blue:8080`.

### Task 13 – DORA queries (6 points) · Domain 4
Write three PromQL queries (one per line) to `/tmp/m4-dora.txt` based on the Argo CD metrics:
deployment frequency per app (7 days), change failure rate (7 days), number of apps that are
currently not `Healthy`.

### Task 14 – Broken rollout (8 points) · Domain 4
In namespace `m4-incident`, `web` was just updated – since then the rollout is stuck and the HPA
does not scale. Roll back to the last working revision, fix the HPA problem and set
`revisionHistoryLimit: 5`. Root causes → `/tmp/m4-incident.txt`.

### Task 15 – Least privilege (5 points) · Domain 5
ServiceAccount `deployer` in namespace `m4-ci` may, in namespace `m4-incident`, **only** read and
patch the Deployment `web` – no other Deployments.

### Task 16 – Pod Security Admission (5 points) · Domain 5
Namespace `m4-secure`: PSA `enforce=restricted` and `warn=restricted`. Create a pod `hardened`
there (image `busybox:1.36`, command `sleep 3600`) that is running.

### Task 17 – Audit trail (5 points) · Domain 5
The ConfigMap `m4-evidence` in namespace `m4-blue` was deleted. Find out from the API audit log
who did it and write the username to `/tmp/m4-audit.txt`.

---

**Total: 100 points.** Solutions: [`SOLUTIONS.md`](SOLUTIONS.md) · Scoring: `./mock-exams/exam-4/verify.sh`
