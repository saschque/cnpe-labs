# Domain 1 – Platform Architecture and Infrastructure (15 %)

Competencies from the curriculum:
- Applying platform architecture best practices for networking, storage, and compute
- Using cost management solutions for right-sizing and scaling
- Optimizing multi-tenancy resource usage

Tools needed: `./setup/install.sh prometheus opencost` (only for 1.6)

---

## Task 1.1 – Tenant namespace with quota ⏱ 6 min

📖 Docs: [Resource quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) · [Limit ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)

The **payments** team gets its own namespace.

1. Create the namespace `team-payments` with the labels `team=payments` and `tier=prod`.
2. Create a `ResourceQuota` named `payments-quota`:
   - `requests.cpu: 4`, `requests.memory: 8Gi`
   - `limits.cpu: 8`, `limits.memory: 16Gi`
   - max. `20` pods, max. `5` PersistentVolumeClaims, max. `0` services of type LoadBalancer
3. Create a `LimitRange` named `payments-defaults` so that containers without settings
   automatically get `100m`/`128Mi` requests and `500m`/`512Mi` limits. A container may request
   at most `2` CPU and `2Gi` memory as a limit.

**Check:** A pod without `resources` starts and has the defaults applied afterwards.

---

## Task 1.2 – Horizontal Pod Autoscaler ⏱ 5 min

📖 Docs: [HPA](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/) · [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

1. In namespace `team-payments`, create a Deployment `checkout` (image
   `registry.k8s.io/hpa-example`, 1 replica, request `cpu: 200m`, port 80) and a ClusterIP
   service `checkout` on port 80.
2. Create an HPA (`autoscaling/v2`) `checkout`: min. 2, max. 8 replicas, target CPU
   utilization 60 %.
3. Configure the scale-down behavior: stabilization window 120 s, remove at most 1 pod per 60 s.

**Bonus:** Generate load and watch the scaling:
```bash
kubectl -n team-payments run load --rm -it --image=busybox -- \
  sh -c 'while true; do wget -q -O- http://checkout; done'
```

---

## Task 1.3 – Availability: PriorityClass & PodDisruptionBudget ⏱ 5 min

📖 Docs: [Pod priority](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/) · [PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) · [Topology spread](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

1. Create a `PriorityClass` `platform-critical` with value `1000000`, not the global default,
   description "Critical platform components".
2. Patch the Deployment `checkout` to use this PriorityClass.
3. Create a `PodDisruptionBudget` `checkout-pdb` that ensures at least 1 `checkout` pod always
   stays available.
4. Spread the `checkout` pods evenly across nodes with `topologySpreadConstraints`
   (`maxSkew: 1`, `whenUnsatisfiable: ScheduleAnyway`).

---

## Task 1.4 – Network isolation between tenants ⏱ 7 min

📖 Docs: [Network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

1. In namespace `team-payments`, create a NetworkPolicy `default-deny` that blocks **all**
   ingress and egress traffic.
2. Create a NetworkPolicy `allow-dns` that allows egress to CoreDNS (namespace `kube-system`,
   label `k8s-app=kube-dns`, UDP/TCP 53).
3. Create a NetworkPolicy `allow-from-frontend` that allows ingress to pods with
   `app=checkout` on port 80 only from namespaces with the label `team=frontend`.
4. Also allow ingress within the namespace (pod-to-pod) – `allow-same-namespace`.

> Note: kind's default CNI (kindnet) supports NetworkPolicies from v0.24. With older versions,
> install Calico, otherwise the policies have no effect.

---

## Task 1.5 – Storage ⏱ 5 min

📖 Docs: [Storage classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) · [Persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) · [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)

1. Create a StorageClass `fast-retain` with the cluster's provisioner (in kind:
   `rancher.io/local-path`), `reclaimPolicy: Retain`, `volumeBindingMode: WaitForFirstConsumer`
   and `allowVolumeExpansion: true`.
2. In namespace `team-payments`, create a PVC `ledger-data` (1Gi, `ReadWriteOnce`) with this
   StorageClass.
3. Explain (to yourself) why the PVC stays `Pending` until a pod uses it. Then create a pod
   `ledger` that mounts the PVC at `/data`.

---

## Task 1.6 – Cost with OpenCost ⏱ 8 min

📖 Docs: [OpenCost API](https://opencost.io/docs/integrations/api/) · [API examples](https://opencost.io/docs/integrations/api-examples/)

1. Make sure OpenCost is running (`./setup/install.sh prometheus opencost`).
2. Use the OpenCost API to get the cost of the last 24 h, **aggregated per namespace**, and
   save the output to `/tmp/cost-by-namespace.json`.
3. Find the namespace with the highest total cost and write only its name to
   `/tmp/top-namespace.txt`.
4. Bonus: aggregate by the label `team` instead.

> 💡 The `opencost` Service exposes two ports – one for the API, one for the web UI. Check
> `kubectl -n opencost get svc opencost` and port-forward the right one. If you get HTML back,
> you're talking to the UI.
>
> 💡 **Reaching OpenCost in the cluster** – two ways:
> - **From your laptop:** `kubectl -n opencost port-forward svc/opencost <local-port>:<svc-port> &`,
>   then `curl http://localhost:<local-port>/...`. Stop it later with `kill %1`.
> - **From inside the cluster:** the Service DNS name is `opencost.opencost.svc.cluster.local`
>   (or `opencost.opencost` from another namespace), e.g. with a throwaway pod:
>   `kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- curl -s http://opencost.opencost:<svc-port>/...`
>
> On a fresh install OpenCost needs a few minutes of Prometheus data before the API returns
> costs – empty results right after `install.sh` are normal. Check that the pod is ready with
> `kubectl -n opencost get pods`.

---

## Task 1.7 – Right-sizing ⏱ 6 min

📖 Docs: [Resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) · [kubectl top pod](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/kubectl_top_pod/)

An oversized Deployment runs in namespace `rightsizing`:
```bash
kubectl apply -f 01-platform-architecture/solutions/rightsizing-setup.yaml
```
1. Use `kubectl top pod` to find the actual usage of the `oversized` pods.
2. Adjust the requests to roughly 1.2× the measured usage (at least `10m` CPU / `16Mi` memory).
   Set the memory limit to twice the request, and **no** CPU limit.
3. Reduce the replicas from 6 to 2.

---

## Task 1.8 – Self-service tenants with Kustomize ⏱ 8 min

📖 Docs: [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) · [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

Create a Kustomize base in `/tmp/tenants/base` and two overlays in
`/tmp/tenants/overlays/team-a` and `/tmp/tenants/overlays/team-b`.

The base contains:
- ResourceQuota `tenant-quota`: `requests.cpu: 1`, `requests.memory: 2Gi`, `pods: 20`
- LimitRange `tenant-defaults`: container default request `100m` CPU / `128Mi` memory,
  default limit `500m` CPU / `512Mi` memory
- NetworkPolicy `default-deny`: denies all ingress traffic to all pods
- RoleBinding `devs-edit`: binds the ClusterRole `edit` to the group `team-a-devs` or `team-b-devs`

Each overlay creates the namespace `team-a` or `team-b` and deploys all base objects into it.
Set `tenant-quota` `requests.cpu` to `2` for team-a and `6` for team-b.

Apply both overlays with `kubectl apply -k`.

---

# More exercises

## Task 1.9 – Dedicated node pool (taints & affinity) ⏱ 6 min

📖 Docs: [Taints & tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) · [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)

> Needs the full cluster with worker nodes (`./setup/create-cluster.sh` without `--lite`).
> Works on 8 GB as long as no add-ons are installed.

Platform components should run on their own nodes.
1. Label the node `cnpe-worker2` with `pool=platform` and taint it with
   `dedicated=platform:NoSchedule`.
2. In namespace `platform-system`, create a Deployment `platform-agent`
   (image `registry.k8s.io/pause:3.10`, 2 replicas) that
   - tolerates the taint and
   - only runs on nodes with `pool=platform` via **required** node affinity.
3. Check that both pods run on `cnpe-worker2` and that a normal Deployment does **not** land there.

> Clean up afterwards (otherwise you lose capacity): `kubectl taint node cnpe-worker2 dedicated-`

---

## Task 1.10 – StatefulSet with a headless service ⏱ 7 min

📖 Docs: [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) · [Headless services](https://kubernetes.io/docs/concepts/services-networking/service/) · [DNS for pods & services](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

1. In namespace `data`, create a headless service `kv` (port 6379).
2. Create a StatefulSet `kv` with 3 replicas (image `redis:7`) that uses this service and mounts
   one volume `data` (256Mi, StorageClass `standard`) per pod at `/data` via `volumeClaimTemplates`.
3. Check that `kv-0.kv.data.svc.cluster.local` resolves via DNS and that 3 PVCs are bound.
4. Scale down to 1 replica. What happens to the PVCs? (keyword `persistentVolumeClaimRetentionPolicy`)

---

## Task 1.11 – Scoped quotas ⏱ 5 min

📖 Docs: [Quota scopes](https://kubernetes.io/docs/concepts/policy/resource-quotas/) · [Pod QoS classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)

In namespace `team-payments`:
1. Quota `critical-quota`: at most **4 pods** with the PriorityClass `platform-critical`
   (`scopeSelector`).
2. Quota `no-besteffort`: **no** BestEffort pods (pods without requests/limits) allowed.
3. Explain why the LimitRange from 1.1 normally prevents BestEffort pods in this namespace anyway.

---

## Task 1.12 – Capacity analysis ⏱ 7 min

📖 Docs: [Resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) · [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) · [JSONPath](https://kubernetes.io/docs/reference/kubectl/jsonpath/)

> Works best on the full cluster with worker nodes (not `--lite`).

For every node, calculate the sum of the **CPU requests** of all running pods in millicores and
write it to `/tmp/node-requests.txt` (format: `<node> <millicores>`, one line per node).
Also write the namespace with the highest CPU requests to `/tmp/top-requests-ns.txt`.

Tip: `kubectl describe node` shows "Allocated resources" – but in the exam, a reproducible
`jq` one-liner is faster and less error-prone.

---

✅ Check: `./01-platform-architecture/verify.sh`
📖 Solutions: [`solutions/`](solutions/)
