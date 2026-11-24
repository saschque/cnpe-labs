# Mock Exam 3 – Solutions

> Only read after the 120 minutes are up!

### 1 – Egress NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: web-egress, namespace: m3-app}
spec:
  podSelector: {matchLabels: {app: web}}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: m3-db}}
          podSelector: {matchLabels: {app: postgres}}
      ports: [{protocol: TCP, port: 5432}]
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
          podSelector: {matchLabels: {k8s-app: kube-dns}}
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
```

### 2 – StatefulSet
```yaml
apiVersion: v1
kind: Service
metadata: {name: cache, namespace: m3-db}
spec:
  clusterIP: None
  selector: {app: cache}
  ports: [{port: 6379}]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: cache, namespace: m3-db}
spec:
  serviceName: cache
  replicas: 2
  selector: {matchLabels: {app: cache}}
  template:
    metadata: {labels: {app: cache}}
    spec:
      containers:
        - name: redis
          image: redis:7
          volumeMounts: [{name: data, mountPath: /data}]
  volumeClaimTemplates:
    - metadata: {name: data}
      spec:
        accessModes: [ReadWriteOnce]
        storageClassName: standard
        resources: {requests: {storage: 128Mi}}
```

### 3 – HPA with behavior
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: m3-app}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource: {name: cpu, target: {type: Utilization, averageUtilization: 50}}
  behavior:
    scaleUp:
      policies: [{type: Pods, value: 2, periodSeconds: 30}]
    scaleDown:
      stabilizationWindowSeconds: 300
```

### 4 – Argo CD ignoreDifferences
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: m3-guestbook, namespace: argocd}
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook
  destination: {server: https://kubernetes.default.svc, namespace: m3-gb}
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: [/spec/replicas]
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true    # otherwise the sync still overwrites the field
```

### 5 – Fix Flux
Error 1: the branch `main` does not exist (podinfo uses `master`) → `GitRepository` not Ready.
Error 2: path `./kustomise` instead of `./kustomize`. In addition, the namespace `m3-flux` is missing.
```bash
kubectl -n flux-system patch gitrepository m3-podinfo --type=merge -p '{"spec":{"ref":{"branch":"master"}}}'
kubectl -n flux-system patch kustomization m3-podinfo --type=merge -p '{"spec":{"path":"./kustomize"}}'
kubectl create ns m3-flux
flux reconcile kustomization m3-podinfo --with-source
flux get kustomizations m3-podinfo
```

### 6 – Tekton results
```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: m3-version, namespace: ci}
spec:
  params: [{name: build-number}]
  results: [{name: tag}]
  steps:
    - name: tag
      image: alpine
      script: echo -n "v1.0.$(params.build-number)" > $(results.tag.path)
---
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: m3-publish, namespace: ci}
spec:
  params: [{name: tag}]
  steps:
    - {name: publish, image: alpine, script: 'echo "publishing app:$(params.tag)"'}
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: m3-build, namespace: ci}
spec:
  params: [{name: build-number}]
  results:
    - name: tag
      value: $(tasks.version.results.tag)
  tasks:
    - name: version
      taskRef: {name: m3-version}
      params: [{name: build-number, value: $(params.build-number)}]
    - name: publish
      taskRef: {name: m3-publish}
      params: [{name: tag, value: $(tasks.version.results.tag)}]
```
```bash
tkn pipeline start m3-build -n ci -p build-number=42 --showlog
kubectl -n ci get pipelinerun -l tekton.dev/pipeline=m3-build -o jsonpath='{.items[0].status.results}'
```
`echo -n` matters – otherwise the result ends with a newline.

### 7 – Retry & exit handler
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata: {name: m3-deploy, namespace: argo}
spec:
  serviceAccountName: argo-workflow
  entrypoint: deploy
  onExit: notify
  templates:
    - name: deploy
      retryStrategy: {limit: "2"}
      container: {image: alpine, command: [echo], args: [deploying]}
    - name: notify
      container: {image: alpine, command: [echo], args: ["status: {{workflow.status}}"]}
```

### 8 – Flagger Canary
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata: {name: podinfo, namespace: m3-canary}
spec:
  targetRef: {apiVersion: apps/v1, kind: Deployment, name: podinfo}
  service: {port: 9898}
  analysis:
    interval: 20s
    threshold: 3
    maxWeight: 30
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange: {min: 99}
        interval: 1m
```
`kubectl -n m3-canary get canary` → `Initialized`; Flagger created `podinfo-primary` and scaled
the original Deployment to 0.

### 9 – CRD with two versions
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: tenants.platform.m3.io}
spec:
  group: platform.m3.io
  scope: Cluster
  names: {kind: Tenant, plural: tenants, singular: tenant}
  versions:
    - name: v1alpha1
      served: true
      storage: false
      deprecated: true
      subresources: {status: {}}
      schema: &s
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [team]
              properties:
                team: {type: string}
                cpuQuota: {type: integer, minimum: 1, maximum: 64}
            status:
              type: object
              properties:
                phase: {type: string}
    - name: v1
      served: true
      storage: true
      subresources: {status: {}}
      schema: *s
---
apiVersion: platform.m3.io/v1
kind: Tenant
metadata: {name: red}
spec: {team: red, cpuQuota: 8}
```
```bash
kubectl patch tenant red --subresource=status --type=merge -p '{"status":{"phase":"Active"}}'
```

### 10 – Crossplane API
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: webservices.platform.m3.io}
spec:
  scope: Namespaced
  group: platform.m3.io
  names: {kind: WebService, plural: webservices}
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [image]
              properties:
                image: {type: string}
                replicas: {type: integer, default: 1}
            status:
              type: object
              properties:
                readyReplicas: {type: integer}
---
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: webservice}
spec:
  compositeTypeRef: {apiVersion: platform.m3.io/v1alpha1, kind: WebService}
  mode: Pipeline
  pipeline:
    - step: pt
      functionRef: {name: function-patch-and-transform}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: deployment
            base:
              apiVersion: apps/v1
              kind: Deployment
              spec:
                selector: {matchLabels: {}}
                template:
                  metadata: {labels: {}}
                  spec:
                    containers: [{name: app, image: placeholder, ports: [{containerPort: 80}]}]
            patches:
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: metadata.name}
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: "spec.selector.matchLabels[app]"}
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: "spec.template.metadata.labels[app]"}
              - {type: FromCompositeFieldPath, fromFieldPath: spec.image, toFieldPath: "spec.template.spec.containers[0].image"}
              - {type: FromCompositeFieldPath, fromFieldPath: spec.replicas, toFieldPath: spec.replicas}
              - {type: ToCompositeFieldPath, fromFieldPath: status.readyReplicas, toFieldPath: status.readyReplicas}
            readinessChecks:
              - type: MatchCondition
                matchCondition: {type: Available, status: "True"}
          - name: service
            base:
              apiVersion: v1
              kind: Service
              spec:
                selector: {}
                ports: [{port: 80, targetPort: 80}]
            patches:
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: metadata.name}
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: "spec.selector[app]"}
            readinessChecks:
              - type: None
---
apiVersion: platform.m3.io/v1alpha1
kind: WebService
metadata: {name: shop, namespace: m3-app}
spec: {image: "nginx:1.27", replicas: 2}
```

### 11 – Kyverno generate
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: m3-tenant-bootstrap}
spec:
  rules:
    - name: netpol
      match:
        any:
          - resources:
              kinds: [Namespace]
              selector: {matchLabels: {m3-tenant: "true"}}
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-ingress
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec: {podSelector: {}, policyTypes: [Ingress]}
    - name: limitrange
      match:
        any:
          - resources:
              kinds: [Namespace]
              selector: {matchLabels: {m3-tenant: "true"}}
      generate:
        apiVersion: v1
        kind: LimitRange
        name: defaults
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            limits:
              - type: Container
                defaultRequest: {cpu: 100m, memory: 128Mi}
```
If Kyverno has no permissions on LimitRanges: add a ClusterRole with the label
`rbac.kyverno.io/aggregate-to-background-controller: "true"` (see solution 3.6).

### 12 – Self-service workflow
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata: {name: m3-new-service, namespace: argo}
spec:
  serviceAccountName: m3-provisioner
  entrypoint: create
  arguments:
    parameters: [{name: name}]
  templates:
    - name: create
      resource:
        action: create
        manifest: |
          apiVersion: platform.m3.io/v1alpha1
          kind: WebService
          metadata:
            name: {{workflow.parameters.name}}
            namespace: m3-app
          spec:
            image: nginx:1.27
```
```bash
argo submit -n argo --from workflowtemplate/m3-new-service -p name=orders --watch
```

### 13 – Fix the ServiceMonitor
Error 1: selector `app: pod-info` does not match the service label `app: podinfo`.
Error 2: endpoint port `http`, but the service port is called `web`.
```bash
kubectl -n m3-mon patch servicemonitor podinfo --type=merge \
  -p '{"spec":{"selector":{"matchLabels":{"app":"podinfo"}},"endpoints":[{"port":"web","path":"/metrics","interval":"15s"}]}}'
```

### 14 – Alert & Query
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: {name: m3-rules, namespace: monitoring}
spec:
  groups:
    - name: m3
      rules:
        - alert: M3NodeMemoryHigh
          expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9
          for: 5m
          labels: {severity: warning}
```
```bash
echo 'topk(3, sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="m3-app", container!=""}[5m])))' > /tmp/m3-query.txt
```

### 15 – Incident
1. `worker`: `CreateContainerConfigError` – the ConfigMap has the key `QUEUE`, not `QUEUE_NAME`.
2. `frontend`: the NetworkPolicy `deny-all-egress` also blocks DNS.
```bash
kubectl -n m3-incident patch deploy worker --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/key","value":"QUEUE"}]'
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: m3-incident}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
          podSelector: {matchLabels: {k8s-app: kube-dns}}
      ports: [{protocol: UDP, port: 53}, {protocol: TCP, port: 53}]
EOF
printf 'worker: ConfigMap key QUEUE_NAME does not exist (it is QUEUE)\nfrontend: deny-all-egress blocks DNS\n' > /tmp/m3-incident.txt
```

### 16 – Istio
```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: {name: default, namespace: m3-mesh}
spec:
  mtls: {mode: STRICT}
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: {name: httpbin-get-only, namespace: m3-mesh}
spec:
  selector: {matchLabels: {app: httpbin}}
  action: ALLOW
  rules:
    - from: [{source: {principals: ["cluster.local/ns/m3-mesh/sa/sleep"]}}]
      to: [{operation: {methods: ["GET"]}}]
```
An ALLOW policy on a workload automatically denies everything that matches no rule –
an additional `deny-all` is not needed here.

### 17 – Gatekeeper
ConstraintTemplate `k8sallowedrepos` as in solution 5.7 (bonus), plus:
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata: {name: m3-registries}
spec:
  enforcementAction: deny
  match:
    kinds: [{apiGroups: [""], kinds: [Pod]}]
    namespaces: [m3-restricted]
  parameters:
    repos: ["registry.k8s.io/", "ghcr.io/"]
```
