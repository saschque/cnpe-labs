#!/usr/bin/env bash
# Prepares mock exam 4. Run before starting the timer.
set -euo pipefail

for ns in m4-blue m4-red m4-flux m4-incident m4-ci m4-secure ci; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
# Task 1: workloads with team labels (cost allocation)
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: m4-blue, labels: {team: blue}}
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api, team: blue}}
    spec:
      containers:
        - name: api
          image: nginx:1.27
          resources: {requests: {cpu: 200m, memory: 128Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: batch, namespace: m4-red, labels: {team: red}}
spec:
  replicas: 1
  selector: {matchLabels: {app: batch}}
  template:
    metadata: {labels: {app: batch, team: red}}
    spec:
      containers:
        - name: batch
          image: registry.k8s.io/pause:3.10
          resources: {requests: {cpu: 50m, memory: 32Mi}}
---
# Task 5
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata: {name: m4-charts, namespace: flux-system}
spec:
  type: oci
  interval: 10m
  url: oci://ghcr.io/stefanprodan/charts
---
# Task 6: broken Tekton pipeline (3 errors)
apiVersion: tekton.dev/v1
kind: Task
metadata: {name: m4-linter, namespace: ci}
spec:
  params:
    - {name: path, type: string}
  workspaces:
    - name: source
  steps:
    - name: lint
      image: alpine
      workingDir: $(workspaces.source.path)
      script: |
        echo "linting $(params.path)"
        mkdir -p "$(params.path)" && ls -la "$(params.path)"
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: {name: m4-ci, namespace: ci}
spec:
  workspaces:
    - name: shared
  tasks:
    - name: lint
      taskRef: {name: m4-lint}
      params:
        - {name: dir, value: manifests}
      workspaces:
        - {name: source, workspace: shared}
---
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: {name: m4-ci-run-1, namespace: ci}
spec:
  pipelineRef: {name: m4-ci}
---
# Task 7: suspended CronWorkflow
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata: {name: m4-report, namespace: argo}
spec:
  schedules: ["0 6 * * 1"]
  suspend: true
  workflowSpec:
    serviceAccountName: argo-workflow
    entrypoint: report
    templates:
      - name: report
        container: {image: alpine, command: [echo], args: ["weekly report"]}
---
# Task 9: Crossplane with two errors
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-patch-and-transform}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: m4-crossplane-configmaps
  labels: {rbac.crossplane.io/aggregate-to-crossplane: "true"}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["*"]
---
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: queues.messaging.m4.io}
spec:
  scope: Namespaced
  group: messaging.m4.io
  names: {kind: Queue, plural: queues}
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
              required: [retentionDays]
              properties:
                retentionDays: {type: integer}
---
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata: {name: queue-configmap}
spec:
  compositeTypeRef: {apiVersion: messaging.m4.io/v1beta1, kind: Queue}
  mode: Pipeline
  pipeline:
    - step: pt
      functionRef: {name: function-patch-and-transform}
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: cm
            base: {apiVersion: v1, kind: ConfigMap, data: {}}
            patches:
              - {type: FromCompositeFieldPath, fromFieldPath: metadata.name, toFieldPath: metadata.name}
              - {type: FromCompositeFieldPath, fromFieldPath: spec.retentionDays, toFieldPath: data.retention}
            readinessChecks:
              - type: None
---
# Task 11: CRD without a controller + object with a finalizer
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: widgets.legacy.m4.io}
spec:
  group: legacy.m4.io
  scope: Namespaced
  names: {kind: Widget, plural: widgets, singular: widget}
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema: {type: object, x-kubernetes-preserve-unknown-fields: true}
---
# Task 14: working version first
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: m4-incident}
spec:
  replicas: 2
  revisionHistoryLimit: 2
  strategy: {rollingUpdate: {maxUnavailable: 0, maxSurge: 1}}
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
        - name: web
          image: nginx:1.27
          resources: {requests: {cpu: 20m, memory: 32Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: worker, namespace: m4-incident}
spec:
  replicas: 1
  selector: {matchLabels: {app: worker}}
  template:
    metadata: {labels: {app: worker}}
    spec:
      containers:
        - {name: worker, image: registry.k8s.io/pause:3.10}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: m4-incident}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web-app}
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource: {name: cpu, target: {type: Utilization, averageUtilization: 70}}
---
# Task 17: evidence + permissions for user "mallory"
apiVersion: v1
kind: ConfigMap
metadata: {name: m4-evidence, namespace: m4-blue}
data: {note: "do not delete"}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: cm-cleaner, namespace: m4-blue}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: cm-cleaner, namespace: m4-blue}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: cm-cleaner}
subjects:
  - {apiGroup: rbac.authorization.k8s.io, kind: User, name: mallory}
EOF

# Task 9: XR (after the XRD is established)
kubectl wait --for=condition=Established xrd/queues.messaging.m4.io --timeout=120s
kubectl apply -f - <<'EOF'
apiVersion: messaging.m4.io/v1alpha1
kind: Queue
metadata: {name: jobs, namespace: m4-blue}
spec:
  retentionDays: 14
  crossplane:
    compositionRef: {name: queue-configmap}
EOF

# Task 11: object with a finalizer, then delete it (stays Terminating)
kubectl wait --for=condition=Established crd/widgets.legacy.m4.io --timeout=60s
kubectl apply -f - <<'EOF'
apiVersion: legacy.m4.io/v1
kind: Widget
metadata:
  name: stuck
  namespace: m4-blue
  finalizers: ["legacy.m4.io/cleanup"]
spec: {size: 1}
EOF
kubectl -n m4-blue delete widget stuck --wait=false

# Task 14: broken update
kubectl -n m4-incident rollout status deploy web --timeout=180s
kubectl -n m4-incident set image deploy/web web=nginx:1.27-hardened

# Task 17: deletion as user mallory (shows up in the audit log)
kubectl -n m4-blue delete configmap m4-evidence --as=mallory

echo "✅ Mock exam 4 ready. Start the timer: 120 minutes."
