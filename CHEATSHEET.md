# CNPE Cheatsheet

## Allgemein
```bash
alias k=kubectl; export do="--dry-run=client -o yaml"
k config use-context <ctx>                       # IMMER zuerst!
k create deploy x --image=nginx:1.27 $do > x.yaml
k explain <kind>.spec --recursive | less
k api-resources --api-group=<group>
k get events -A --sort-by=.lastTimestamp | tail
k auth can-i <verb> <res> -n <ns> --as=<user> [--as-group=<g>]
k auth can-i --list --as=system:serviceaccount:<ns>:<sa>
k get <res> -o jsonpath='{.status.conditions}' | jq
k patch <res> --type=json -p='[{"op":"replace","path":"/spec/...","value":...}]'
k apply --dry-run=server -f x.yaml               # Validierung inkl. Admission-Webhooks
```

## Argo CD
```bash
argocd login <server> --insecure --username admin --password <pw>   # oder: argocd login --core
argocd app list | get <app> | diff <app> | sync <app> | history <app> | rollback <app> <id>
argocd app get <app> --hard-refresh
argocd app set <app> --sync-policy automated --auto-prune --self-heal
k -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```
Annotations: `argocd.argoproj.io/sync-wave: "-1"`, `argocd.argoproj.io/hook: PreSync|Sync|PostSync|SyncFail`,
`argocd.argoproj.io/hook-delete-policy: HookSucceeded|HookFailed|BeforeHookCreation`.

## Flux
```bash
flux check
flux get all -A
flux create source git|helm|oci ... --export
flux create kustomization|helmrelease ... --export
flux reconcile kustomization <n> --with-source
flux suspend|resume kustomization <n>
flux logs --level=error
flux events
```

## Tekton
```bash
tkn task|pipeline list -n <ns>
tkn pipeline start <p> -p k=v -w name=shared,volumeClaimTemplateFile=pvc.yaml --showlog
tkn pipelinerun logs --last -f
tkn pipelinerun describe --last
```
Variablen: `$(params.x)`, `$(workspaces.w.path)`, `$(results.r.path)`, `$(tasks.t.results.r)`.

## Argo Workflows
```bash
argo submit -n argo wf.yaml --watch | argo submit --from workflowtemplate/<t> -p k=v
argo list | get @latest | logs @latest | retry <wf> | resubmit <wf>
argo template list | argo cron list
```
Variablen: `{{inputs.parameters.x}}`, `{{workflow.parameters.x}}`, `{{steps.s.outputs.result}}`,
`{{tasks.t.outputs.parameters.p}}`. DAG: `depends: "a && b"`.

## Crossplane
```bash
k get xrd ; k get composition ; k get functions ; k get providers
k get managed                    # alle Managed Resources (v1 Provider)
crossplane beta trace <kind> <name> [-n ns]
k -n crossplane-system logs deploy/crossplane
```
XRD = Schema · XR = Instanz · Composition = Rezept. Patches: `FromCompositeFieldPath`,
`ToCompositeFieldPath`, `CombineFromComposite`, `CombineToComposite`; Transforms: `convert`,
`map`, `string` (fmt), `math`.

## Kyverno
```bash
k get clusterpolicy ; k get policyreport -A ; k get updaterequests -n kyverno
kyverno apply policy.yaml --resource res.yaml
kyverno test .
```
Pattern-Operatoren: `?*` (nicht leer), `!value`, `>0`, `(name): "*"` (Anker), `+(field)` (nur hinzufügen),
`=(field)` (wenn vorhanden, dann…).

## Gatekeeper
```bash
k get constrainttemplates ; k get constraints
k get <kind-lowercase> <name> -o json | jq '.status.violations'
```
`enforcementAction: deny | dryrun | warn`.

## Prometheus / PromQL
```promql
sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
histogram_quantile(0.95, sum by (le) (rate(<metric>_bucket[5m])))
topk(5, increase(kube_pod_container_status_restarts_total[1h]))
```
CRDs: `ServiceMonitor`, `PodMonitor`, `PrometheusRule`, `AlertmanagerConfig`.
Selektoren prüfen: `k -n monitoring get prometheus -o yaml | grep -A3 Selector`.

## Istio / Linkerd
```bash
k label ns <ns> istio-injection=enabled         # Istio: Label
k annotate ns <ns> linkerd.io/inject=enabled    # Linkerd: Annotation
istioctl analyze -n <ns> ; istioctl x describe pod <pod>
linkerd check --proxy ; linkerd viz edges deploy -n <ns>
```
Istio: `PeerAuthentication` (mTLS-Modus), `AuthorizationPolicy` (ALLOW/DENY, principals
`cluster.local/ns/<ns>/sa/<sa>`), `VirtualService`/`DestinationRule` (Traffic).

## OpenCost
```bash
k -n opencost port-forward svc/opencost 9003
curl -sG localhost:9003/allocation/compute -d window=24h -d aggregate=namespace -d accumulate=true | jq
```

## Troubleshooting-Reihenfolge
Events → `describe` → `logs [--previous]` → Endpoints/Selectors → Quotas/LimitRanges →
Policies (Kyverno/Gatekeeper/PSA/NetworkPolicy) → Controller-Logs.
