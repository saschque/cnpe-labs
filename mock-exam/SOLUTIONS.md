# Mock Exam – Lösungen

> Erst nach Ablauf der 120 Minuten lesen!

### 1 – Mandanten-Quota
```bash
kubectl -n mx-team-red create quota red-quota --hard=requests.cpu=3,requests.memory=6Gi,pods=15
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: LimitRange
metadata: {name: red-defaults, namespace: mx-team-red}
spec:
  limits:
    - type: Container
      defaultRequest: {cpu: 50m, memory: 64Mi}
      default: {cpu: 250m, memory: 256Mi}
EOF
```

### 2 – HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: api, namespace: mx-team-red}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: api}
  minReplicas: 3
  maxReplicas: 12
  metrics:
    - type: Resource
      resource: {name: cpu, target: {type: Utilization, averageUtilization: 70}}
    - type: Resource
      resource: {name: memory, target: {type: Utilization, averageUtilization: 80}}
```

### 3 – NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: db-allow-api, namespace: mx-team-red}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: {matchLabels: {app: api}}
      ports:
        - {protocol: TCP, port: 5432}
```
Sobald eine Policy `app=db` mit `policyTypes: [Ingress]` auswählt, ist alles andere verboten.

### 4 – Argo CD mit Kustomize-Option
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: mx-kustomize, namespace: argocd}
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: kustomize-guestbook
    kustomize:
      namePrefix: mx-
  destination: {server: https://kubernetes.default.svc, namespace: mx-gb}
  syncPolicy:
    automated: {prune: true}
    syncOptions: [CreateNamespace=true]
```

### 5 – Argo CD Troubleshooting
Zwei Fehler: `targetRevision: mainn` (Branch existiert nicht; das Repo nutzt `master`) und
`valueFiles: values-prod.yaml` (Datei existiert nicht, richtig: `values-production.yaml`).
```bash
kubectl -n argocd get application mx-broken -o jsonpath='{.status.conditions}' | jq
kubectl -n argocd patch application mx-broken --type=merge -p '
spec:
  source:
    targetRevision: HEAD
    helm:
      valueFiles: ["values-production.yaml"]'
```

### 6 – Flux HelmRelease
```bash
kubectl create ns mx-flux
flux create source helm mx-podinfo --url=oci://ghcr.io/stefanprodan/charts -n flux-system
flux create helmrelease mx-podinfo -n mx-flux --source=HelmRepository/mx-podinfo.flux-system \
  --chart=podinfo --interval=2m --values=<(echo 'replicaCount: 3')
```
(`flux create source helm` erkennt `oci://` automatisch als Typ OCI.) Oder YAML wie in Lösung 2.5.

### 7 – Argo Workflows
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata: {name: mx-pipeline, namespace: argo}
spec:
  serviceAccountName: argo-workflow
  entrypoint: main
  arguments:
    parameters: [{name: env, value: dev}]
  templates:
    - name: main
      steps:
        - - name: test
            template: say
            arguments: {parameters: [{name: step, value: test}]}
        - - name: deploy
            template: say
            arguments: {parameters: [{name: step, value: deploy}]}
    - name: say
      inputs: {parameters: [{name: step}]}
      container:
        image: alpine
        command: [echo]
        args: ["{{inputs.parameters.step}} to {{workflow.parameters.env}}"]
```
```bash
argo submit -n argo --from workflowtemplate/mx-pipeline -p env=staging --watch
```

### 8 – Tekton mit Results
```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: mx-hello, namespace: ci}
spec:
  params: [{name: name, type: string}]
  results: [{name: greeting}]
  steps:
    - name: hello
      image: alpine
      script: |
        echo -n "Hallo $(params.name)" > $(results.greeting.path)
---
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: mx-print, namespace: ci}
spec:
  params: [{name: text, type: string}]
  steps:
    - name: print
      image: alpine
      script: echo "$(params.text)"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: mx-greet, namespace: ci}
spec:
  params: [{name: name, default: CNPE}]
  tasks:
    - name: hello
      taskRef: {name: mx-hello}
      params: [{name: name, value: $(params.name)}]
    - name: print
      taskRef: {name: mx-print}
      params: [{name: text, value: $(tasks.hello.results.greeting)}]   # implizite Abhängigkeit
```
```bash
tkn pipeline start mx-greet -n ci -p name=Sascha --showlog
```

### 9 – CRD
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: queues.messaging.example.org}
spec:
  group: messaging.example.org
  scope: Namespaced
  names: {kind: Queue, plural: queues, singular: queue, shortNames: [q]}
  versions:
    - name: v1
      served: true
      storage: true
      additionalPrinterColumns:
        - {name: Max, type: integer, jsonPath: .spec.maxMessages}
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [maxMessages]
              properties:
                maxMessages: {type: integer, minimum: 1, maximum: 10000}
                fifo: {type: boolean, default: false}
---
apiVersion: messaging.example.org/v1
kind: Queue
metadata: {name: orders, namespace: mx-team-red}
spec: {maxMessages: 500}
```

### 10 – Crossplane Composition
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: bucket-configmap}
spec:
  compositeTypeRef: {apiVersion: storage.example.org/v1alpha1, kind: Bucket}
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
              data: {}
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: metadata.name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.sizeGB
                toFieldPath: data.size
                transforms:
                  - type: convert
                    convert: {toType: string}
            readinessChecks:
              - type: None
---
apiVersion: storage.example.org/v1alpha1
kind: Bucket
metadata: {name: logs, namespace: mx-team-red}
spec: {sizeGB: 50}
```
Der `convert`-Transform ist der Knackpunkt: ConfigMap-Daten müssen Strings sein.

### 11 – Kyverno generate
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: mx-platform-info}
spec:
  rules:
    - name: cm
      match:
        any:
          - resources:
              kinds: [Namespace]
              selector: {matchLabels: {mx-tenant: "true"}}
      generate:
        apiVersion: v1
        kind: ConfigMap
        name: platform-info
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          data:
            contact: platform@example.org
```

### 12 – PrometheusRule
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: {name: mx-rules, namespace: monitoring}
spec:
  groups:
    - name: mx
      rules:
        - alert: DeploymentReplicasMismatch
          expr: kube_deployment_spec_replicas != kube_deployment_status_replicas_available
          for: 10m
          labels: {severity: warning}
          annotations:
            summary: "{{ $labels.namespace }}/{{ $labels.deployment }}: Replicas weichen ab"
```

### 13 – Incident
1. `CreateContainerConfigError`: Deployment referenziert ConfigMap `checkout-cfg`, sie heißt `checkout-config`.
2. Service-Selector `version: v1`, Pods haben `version: v2` → keine Endpoints.
```bash
kubectl -n mx-incident patch deploy checkout --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"checkout-config"}]'
kubectl -n mx-incident patch svc checkout --type=json \
  -p='[{"op":"remove","path":"/spec/selector/version"}]'
printf 'ConfigMap-Name falsch (checkout-cfg statt checkout-config)\nService-Selector version=v1 passt nicht zu Pods (v2)\n' > /tmp/mx-incident.txt
```

### 14 – Query
```promql
topk(3, sum by (namespace) (container_memory_working_set_bytes{container!=""}))
```

### 15 – RBAC
```bash
kubectl -n mx-team-red create sa mx-auditor
kubectl create clusterrole mx-auditor --verb=get,list,watch --resource=pods,deployments.apps,events
kubectl create clusterrolebinding mx-auditor --clusterrole=mx-auditor --serviceaccount=mx-team-red:mx-auditor
kubectl auth can-i list secrets -A --as=system:serviceaccount:mx-team-red:mx-auditor   # no
```

### 16 – Kyverno Memory-Limit
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: mx-require-limits}
spec:
  validationFailureAction: Enforce
  rules:
    - name: mem-limit
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [mx-team-red]
      validate:
        message: "Jeder Container braucht ein Memory-Limit."
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
```

### 17 – PSA restricted
```bash
kubectl label ns mx-team-red pod-security.kubernetes.io/enforce=restricted --overwrite
```
nginx läuft als root → Image auf eine unprivilegierte Variante umstellen und securityContext setzen:
```bash
kubectl -n mx-team-red patch deploy api --type=strategic -p '
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: api
          image: nginxinc/nginx-unprivileged:1.27
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}'
kubectl -n mx-team-red rollout status deploy api
```
Das Memory-Limit (Aufgabe 16) ist bereits vorhanden. Das Deployment `db` würde neue Pods
ebenfalls nicht mehr erzeugen dürfen – laufende Pods bleiben aber bestehen (PSA prüft nur bei
der Erstellung). `kubectl label --dry-run=server` zeigt solche Warnungen vorab an.
