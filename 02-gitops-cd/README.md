# Domain 2 – GitOps and Continuous Delivery (25 %)

Competencies from the curriculum:
- Implementing GitOps workflows for application and infrastructure deployment
- Building and configuring CI/CD pipelines integrated with Kubernetes
- Working with Argo Workflows for platform automation
- Deploying applications using progressive delivery strategies

Tools needed: `./setup/install.sh argocd flux tekton argo_workflows`
For 2.9: `./setup/install.sh prometheus istio flagger`

Public example repos:
- `https://github.com/argoproj/argocd-example-apps` (paths: `guestbook`, `helm-guestbook`, `kustomize-guestbook`)
- `https://github.com/stefanprodan/podinfo` (Kustomize under `./kustomize`, Helm chart at `oci://ghcr.io/stefanprodan/charts/podinfo`)

---

## Task 2.1 – Argo CD Application ⏱ 6 min

Create an Argo CD `Application` named `guestbook` in namespace `argocd`:
- Source: `argocd-example-apps`, path `guestbook`, revision `HEAD`
- Destination: in-cluster, namespace `guestbook` (should be created automatically)
- Automated sync with `prune` and `selfHeal`

**Check:** status `Synced` / `Healthy`. Then manually delete the Deployment `guestbook-ui` and
watch Argo CD restore it.

---

## Task 2.2 – ApplicationSet for multiple environments ⏱ 8 min

Create an `ApplicationSet` `guestbook-envs` that uses a **list generator** to create three
Applications: `guestbook-dev`, `guestbook-staging`, `guestbook-prod`.
- Source: path `helm-guestbook`
- Destination namespace `gb-<env>`, created automatically
- Helm parameter `replicaCount`: dev=1, staging=2, prod=3
- Only `dev` and `staging` sync automatically, `prod` manually.

---

## Task 2.3 – Sync waves & hooks ⏱ 8 min

`solutions/2.3-waves/manifests.yaml` contains a ConfigMap, a Deployment and two Jobs without
annotations. Add Argo CD annotations so that a sync runs in this order:
1. `Job` `db-migrate` as a **PreSync hook**, deleted after it succeeds
2. `ConfigMap` `app-config` in wave `-1`
3. `Deployment` `web` in wave `0`
4. `Job` `smoke-test` as a **PostSync hook**

Create the namespace `waves`, then deploy the manifests with an Argo CD Application `waves` into
it (manual sync) and sync it once.

Answer: What happens to the Deployment if `db-migrate` fails?

> 💡 Argo CD only syncs from Git. Push your version to a branch of your own repo (e.g. `practice`)
> and point the Application at it. The folder also contains `solution.yaml` with the same
> resources – use `spec.source.directory.include: manifests.yaml` so only your file is applied.
> `CreateNamespace=true` does not help here: Argo CD creates the namespace only after the PreSync
> hooks, so `db-migrate` would fail with "namespace not found".

---

## Task 2.4 – Flux: GitRepository + Kustomization ⏱ 6 min

1. In namespace `flux-system`, create a `GitRepository` `podinfo`
   (URL `https://github.com/stefanprodan/podinfo`, branch `master`, interval 1m).
2. Create a Flux `Kustomization` `podinfo` that deploys the path `./kustomize` into the namespace
   `podinfo`, with `prune: true`, interval 5m and a health check on the Deployment `podinfo`.
3. Suspend the reconciliation, change the replicas manually, resume and force an immediate
   reconciliation.

---

## Task 2.5 – Flux: HelmRelease ⏱ 6 min

1. Create a `HelmRepository` of type **OCI** `podinfo` for `oci://ghcr.io/stefanprodan/charts`.
2. Create a `HelmRelease` `podinfo-helm` in namespace `podinfo-helm`, chart `podinfo`, version
   `>=6.0.0`, with the values `replicaCount: 2` and `ui.message: "Hello CNPE"`.
3. Configure: on failure, max. 3 upgrade retries, then roll back.

---

## Task 2.6 – Troubleshooting: app stuck OutOfSync/Degraded ⏱ 7 min

```bash
kubectl apply -f 02-gitops-cd/solutions/2.6-broken-app.yaml
```
The Application `broken-app` does not sync. Find and fix **all** errors until it is
`Synced`/`Healthy`. Use `argocd app get`, `kubectl describe application` and the conditions.

---

## Task 2.7 – Tekton pipeline ⏱ 10 min

1. Create a Tekton `Task` `lint-yaml` in namespace `ci` that has a parameter `path` and runs
   `yamllint -d relaxed $(params.path)` in the image `cytopia/yamllint` on a workspace `source`.
2. Create a `Pipeline` `ci-pipeline` with two tasks:
   - `clone`: clones a Git repo (parameter `repo-url`) into the workspace – use a simple
     `alpine/git` image (no Hub task needed)
   - `lint`: runs **after** `clone` and uses `lint-yaml`
3. Start a `PipelineRun` against `https://github.com/argoproj/argocd-example-apps` with path
   `guestbook`, workspace via `volumeClaimTemplate` (1Gi).
4. Read the logs with `tkn pipelinerun logs --last -f` (or kubectl).

---

## Task 2.8 – Argo Workflows ⏱ 10 min

1. In namespace `argo`, create a `WorkflowTemplate` `platform-dag` with a DAG:
   ```
        validate
        /      \
   build-a   build-b
        \      /
        publish
   ```
   Every step uses a template `echo` (image `alpine`, prints the parameter `msg`).
2. Start a workflow from the template (`argo submit --from workflowtemplate/platform-dag`).
3. Create a `CronWorkflow` `nightly-cleanup` that runs daily at 02:00 (Europe/Berlin), has
   `concurrencyPolicy: Forbid` and keeps the last 3 successful runs.
4. Bonus: add a `retryStrategy` (limit 3, backoff) to one step.

---

## Task 2.9 – Progressive delivery with Flagger (canary) ⏱ 12 min

Prerequisite: Istio + Prometheus + Flagger installed.
1. Create the namespace `canary-demo` with Istio sidecar injection.
2. Deploy `podinfo` (image `ghcr.io/stefanprodan/podinfo:6.7.0`, port 9898) **without** a service.
3. Create a Flagger `Canary` `podinfo`:
   - analysis interval 30s, threshold 5 failures, max weight 50, step weight 10
   - metrics: `request-success-rate` min. 99 %, `request-duration` max. 500 ms
4. Trigger a canary rollout by updating the image to `6.7.1`, and watch it with
   `kubectl -n canary-demo describe canary podinfo`.
5. How would you switch this to **blue/green**? (keyword `iterations`)

---

# More exercises

## Task 2.10 – Argo CD AppProject as a guardrail ⏱ 8 min

Create an `AppProject` `team-a` in namespace `argocd`:
- Allowed source: only `https://github.com/argoproj/argocd-example-apps`
- Allowed destinations: only in-cluster, namespaces starting with `team-a-`
- Cluster-scoped resources: **only** `Namespace` allowed
- Namespaced blacklist: `ResourceQuota`, `LimitRange`, `NetworkPolicy` (the team must not
  override platform guardrails)
- Project role `ci` with permission to **sync** the project's Applications

Then create two Applications in project `team-a` (source path `guestbook`, auto-sync, namespace
created automatically):
- `team-a-guestbook` with destination namespace `team-a-guestbook` – must be `Synced`/`Healthy`
- `team-a-default` with destination namespace `default` – must be rejected by the project
  (check its conditions)

---

## Task 2.11 – ApplicationSet with the Git directory generator ⏱ 7 min

Create an `ApplicationSet` `example-dirs` that creates an Application for every directory in the
`argocd-example-apps` repo ending in `-guestbook` – **except** `jsonnet-guestbook`.
- Application name = directory name
- Destination namespace `dir-<directory-name>`, created automatically, auto-sync

Bonus: How do you prevent Argo CD from deleting the apps' resources when you delete the
ApplicationSet? (keyword `preserveResourcesOnDeletion`)

---

## Task 2.12 – Flux: staging variant with patches ⏱ 7 min

Create a second Flux `Kustomization` `podinfo-staging` (source: `GitRepository/podinfo` from 2.4,
path `./kustomize`) that
- deploys into the namespace `podinfo-staging`,
- only reconciles once the Kustomization `podinfo` is ready (`dependsOn`),
- sets the `HorizontalPodAutoscaler` `podinfo` to `minReplicas: 3` via a **patch**,
- gives all objects the label `env: staging` (`commonMetadata`).

---

## Task 2.13 – Tekton: `when` and `finally` ⏱ 8 min

In namespace `ci`, create a pipeline `release-gate` with the parameter `environment`:
1. Task `build` – prints "building".
2. Task `approve-prod` – runs after `build`, **only if** `environment` equals `prod`.
3. Task `deploy` – runs after `approve-prod` (and must still run when `approve-prod` was
   skipped).
4. `finally` task `notify` – prints the overall status (`$(tasks.status)`).

Start a run with `environment=dev` and check that `approve-prod` is listed in
`status.skippedTasks`.

---

## Task 2.14 – Argo Workflows: results, conditions, exit handler ⏱ 8 min

Create a `WorkflowTemplate` `coinflip` in namespace `argo`:
1. Step `flip` (script template, image `alpine`) randomly prints `heads` or `tails`.
2. Then in parallel: `heads` only runs on `heads`, `tails` only on `tails`
   (`when` with `{{steps.flip.outputs.result}}`).
3. An exit handler (`onExit`) always prints `Workflow status: {{workflow.status}}`.
4. Run the template three times and check in `argo get` which steps were skipped.

---

✅ Check: `./02-gitops-cd/verify.sh`
📖 Solutions: [`solutions/`](solutions/)
