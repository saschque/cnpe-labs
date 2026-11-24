# Mock Exam 2 – Solutions

> Only read after the 120 minutes are up!

### 1 – Batch pool
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: cruncher, namespace: m2-batch}
spec:
  replicas: 2
  selector: {matchLabels: {app: cruncher}}
  template:
    metadata: {labels: {app: cruncher}}
    spec:
      tolerations:
        - {key: workload, operator: Equal, value: batch, effect: NoSchedule}
      nodeSelector:
        pool: batch            # nodeSelector is enough here; affinity would work too
      containers:
        - name: c
          image: registry.k8s.io/pause:3.10
```
Only a toleration = pods *may* go to the pool but also land elsewhere. Only a nodeSelector =
pods stay `Pending` (taint). Both together = "exclusively".

### 2 – Priority & PDB
```bash
kubectl create priorityclass m2-high --value=100000
kubectl -n m2-shop patch deploy web -p '{"spec":{"template":{"spec":{"priorityClassName":"m2-high"}}}}'
kubectl -n m2-shop create pdb web-pdb --selector=app=web --max-unavailable=1
```

### 3 – Guardrails
```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: m2-ratio, namespace: m2-shop}
spec:
  limits:
    - type: Container
      maxLimitRequestRatio:
        memory: "2"
---
apiVersion: v1
kind: ResourceQuota
metadata: {name: m2-no-besteffort, namespace: m2-shop}
spec:
  hard: {pods: "0"}
  scopes: [BestEffort]
```

### 4 – ApplicationSet
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: {name: m2-dirs, namespace: argocd}
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/argoproj/argocd-example-apps
        revision: HEAD
        directories:
          - path: helm-guestbook
          - path: kustomize-guestbook
  template:
    metadata: {name: 'm2-{{.path.basename}}'}
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'm2-{{.path.basename}}'
      syncPolicy:
        automated: {prune: true, selfHeal: true}
        syncOptions: [CreateNamespace=true]
```

### 5 – AppProject
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: m2-team, namespace: argocd}
spec:
  sourceRepos: [https://github.com/argoproj/argocd-example-apps]
  destinations:
    - {server: https://kubernetes.default.svc, namespace: "m2-team-*"}
  clusterResourceWhitelist:
    - {group: "", kind: Namespace}          # needed for CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: m2-gb, namespace: argocd}
spec:
  project: m2-team
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook
  destination: {server: https://kubernetes.default.svc, namespace: m2-team-gb}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
```
Pitfall: without `Namespace` in the `clusterResourceWhitelist`, `CreateNamespace=true` fails.

### 6 – Flux with a patch
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: {name: m2-podinfo, namespace: flux-system}
spec:
  interval: 5m
  path: ./kustomize
  prune: true
  targetNamespace: m2-flux
  sourceRef: {kind: GitRepository, name: m2-podinfo}
  patches:
    - target: {kind: HorizontalPodAutoscaler, name: podinfo}
      patch: |
        - op: replace
          path: /spec/minReplicas
          value: 3
```
The namespace `m2-flux` must exist: `kubectl create ns m2-flux`.

### 7 – Tekton when/finally
```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: say-name, namespace: ci}
spec:
  params: [{name: name}]
  steps:
    - {name: say, image: alpine, script: 'echo "$(params.name)"'}
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: m2-release, namespace: ci}
spec:
  params:
    - {name: run-tests, default: "true"}
  tasks:
    - name: build
      taskRef: {name: say-name}
      params: [{name: name, value: build}]
    - name: test
      runAfter: [build]
      when:
        - {input: "$(params.run-tests)", operator: in, values: ["true"]}
      taskRef: {name: say-name}
      params: [{name: name, value: test}]
    - name: package
      runAfter: [test]
      taskRef: {name: say-name}
      params: [{name: name, value: package}]
  finally:
    - name: cleanup
      taskRef: {name: say-name}
      params: [{name: name, value: cleanup}]
```
```bash
tkn pipeline start m2-release -n ci -p run-tests=false --showlog
```

### 8 – Argo Workflows fan-out
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata: {name: m2-fanout, namespace: argo}
spec:
  serviceAccountName: argo-workflow
  entrypoint: main
  templates:
    - name: main
      steps:
        - - name: process
            template: say
            arguments: {parameters: [{name: msg, value: "processing {{item}}"}]}
            withItems: [eu, us, asia]
        - - name: summary
            template: say
            arguments: {parameters: [{name: msg, value: done}]}
    - name: say
      inputs: {parameters: [{name: msg}]}
      container: {image: alpine, command: [echo], args: ["{{inputs.parameters.msg}}"]}
```
```bash
argo submit -n argo --from workflowtemplate/m2-fanout --watch
```

### 9 – CRD with CEL
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: environments.platform.m2.io}
spec:
  group: platform.m2.io
  scope: Cluster
  names: {kind: Environment, plural: environments, singular: environment}
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [tier, owner]
              x-kubernetes-validations:
                - rule: "self.tier != 'prod' || has(self.approvedBy)"
                  message: "prod-Environments brauchen approvedBy"
              properties:
                tier: {type: string, enum: [dev, prod]}
                owner: {type: string}
                approvedBy: {type: string}
---
apiVersion: platform.m2.io/v1
kind: Environment
metadata: {name: checkout-prod}       # cluster-scoped → no namespace
spec: {tier: prod, owner: team-red, approvedBy: cto}
```
`has()` checks whether an optional field is set – without `has()`, CEL throws an error for a missing field.

### 10 – Crossplane map transform
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: cache-cm}
spec:
  compositeTypeRef: {apiVersion: cache.m2.io/v1alpha1, kind: Cache}
  mode: Pipeline
  pipeline:
    - step: pt
      functionRef: {name: function-patch-and-transform}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: cm
            base:
              apiVersion: v1
              kind: ConfigMap
              data:
                engine: redis
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: metadata.name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.size
                toFieldPath: data.memory
                transforms:
                  - type: map
                    map: {small: 256Mi, large: 1Gi}
            readinessChecks:
              - type: None
---
apiVersion: cache.m2.io/v1alpha1
kind: Cache
metadata: {name: sessions, namespace: m2-shop}
spec: {size: large}
```

### 11 – RBAC
```bash
kubectl -n m2-shop create role m2-cache-author --verb=get,list,watch,create,delete --resource=caches.cache.m2.io
kubectl -n m2-shop create role m2-cm-reader --verb=get,list,watch --resource=configmaps
kubectl -n m2-shop create rolebinding m2-cache-author --role=m2-cache-author --group=m2-devs
kubectl -n m2-shop create rolebinding m2-cm-reader --role=m2-cm-reader --group=m2-devs
```

### 12 – Guardrail
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: m2-no-large-in-dev}
spec:
  validationFailureAction: Enforce
  rules:
    - name: no-large
      match:
        any:
          - resources:
              kinds: ["cache.m2.io/v1alpha1/Cache"]
              namespaceSelector: {matchLabels: {env: dev}}
      validate:
        message: "Caches of size large are not allowed in dev."
        pattern:
          spec:
            size: "!large"
```

### 13 – Incident
1. Request `memory: 64Gi` → Pods `Pending` (`Insufficient memory`).
2. Liveness probe on `/healthz` → nginx returns 404 → restarts.
```bash
kubectl -n m2-incident set resources deploy api --requests=memory=64Mi
kubectl -n m2-incident patch deploy api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path","value":"/"}]'
kubectl -n m2-incident rollout status deploy api
```

### 14 – SLO alert
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: {name: m2-slo, namespace: monitoring}
spec:
  groups:
    - name: m2-slo
      rules:
        - record: sli:m2_api_errors:ratio_rate5m
          expr: sum(rate(http_requests_total{namespace="m2-shop",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="m2-shop"}[5m]))
        - record: sli:m2_api_errors:ratio_rate1h
          expr: sum(rate(http_requests_total{namespace="m2-shop",status=~"5.."}[1h])) / sum(rate(http_requests_total{namespace="m2-shop"}[1h]))
        - alert: M2ErrorBudgetBurn
          expr: sli:m2_api_errors:ratio_rate1h > (14.4 * 0.001) and sli:m2_api_errors:ratio_rate5m > (14.4 * 0.001)
          for: 2m
          labels: {severity: critical}
```

### 15 – OTel Collector
1. The pipeline references the exporter `otlp`, which is not defined → the collector exits on startup
   (`logs` show: *references exporter "otlp" which is not configured*).
2. The service port `otlp-grpc` points to `targetPort: 14317` instead of `4317`.
```bash
kubectl -n m2-otel edit cm otel-collector-config
```
```yaml
    exporters:
      debug: {}
      otlp:
        endpoint: jaeger.observability:4317
        tls: {insecure: true}
```
```bash
kubectl -n m2-otel rollout restart deploy otel-collector
kubectl -n m2-otel patch svc otel-collector --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":4317}]'
```

### 16 – Pod security with Kyverno
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: m2-restricted}
spec:
  validationFailureAction: Enforce
  rules:
    - name: restricted
      match:
        any:
          - resources: {kinds: [Pod], namespaces: [m2-secure]}
      validate:
        podSecurity: {level: restricted, version: latest}
```
```bash
kubectl -n m2-secure patch deploy app --type=strategic -p '
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: app
          image: nginxinc/nginx-unprivileged:1.27
          ports: [{containerPort: 8080}]
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}'
kubectl -n m2-secure rollout status deploy app
```

### 17 – RBAC audit
```bash
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") | .subjects[]?
  | select(.kind=="ServiceAccount") | "\(.namespace)/\(.name)"' | tee /tmp/m2-admins.txt
kubectl delete clusterrolebinding old-ci-admin
kubectl -n m2-shop create rolebinding old-ci-edit --clusterrole=edit --serviceaccount=m2-shop:old-ci
```
