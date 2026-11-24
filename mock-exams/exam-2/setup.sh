#!/usr/bin/env bash
# Prepares mock exam 2. Run before starting the timer.
set -euo pipefail

for ns in m2-batch m2-shop m2-incident m2-otel m2-secure ci; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl create ns m2-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns m2-dev env=dev --overwrite

# Task 1: batch pool
kubectl label node cnpe-worker pool=batch --overwrite
kubectl taint node cnpe-worker workload=batch:NoSchedule --overwrite

kubectl apply -f - <<'EOF'
# Task 2
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: m2-shop}
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
        - name: web
          image: nginx:1.27
          resources: {requests: {cpu: 20m, memory: 64Mi}, limits: {memory: 128Mi}}
---
# Task 6
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata: {name: m2-podinfo, namespace: flux-system}
spec:
  interval: 5m
  url: https://github.com/stefanprodan/podinfo
  ref: {branch: master}
---
# Task 10: function, RBAC, XRD
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-patch-and-transform}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: m2-crossplane-configmaps
  labels: {rbac.crossplane.io/aggregate-to-crossplane: "true"}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["*"]
---
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: caches.cache.m2.io}
spec:
  scope: Namespaced
  group: cache.m2.io
  names: {kind: Cache, plural: caches}
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
              required: [size]
              properties:
                size: {type: string, enum: [small, large]}
---
# Task 13: two errors
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: m2-incident}
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
        - name: api
          image: nginx:1.27
          resources: {requests: {cpu: 10m, memory: 64Gi}}
          livenessProbe:
            httpGet: {path: /healthz, port: 80}
            periodSeconds: 5
            failureThreshold: 2
---
# Task 15: broken collector
apiVersion: v1
kind: ConfigMap
metadata: {name: otel-collector-config, namespace: m2-otel}
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc: {endpoint: 0.0.0.0:4317}
          http: {endpoint: 0.0.0.0:4318}
    processors:
      batch: {}
    exporters:
      debug: {}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [otlp, debug]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: otel-collector, namespace: m2-otel}
spec:
  selector: {matchLabels: {app: otel-collector}}
  template:
    metadata: {labels: {app: otel-collector}}
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:latest
          args: ["--config=/conf/config.yaml"]
          ports: [{containerPort: 4317}, {containerPort: 4318}]
          volumeMounts: [{name: config, mountPath: /conf}]
      volumes:
        - name: config
          configMap: {name: otel-collector-config}
---
apiVersion: v1
kind: Service
metadata: {name: otel-collector, namespace: m2-otel}
spec:
  selector: {app: otel-collector}
  ports:
    - {name: otlp-grpc, port: 4317, targetPort: 14317}
    - {name: otlp-http, port: 4318, targetPort: 4318}
---
# Task 16
apiVersion: apps/v1
kind: Deployment
metadata: {name: app, namespace: m2-secure}
spec:
  replicas: 1
  selector: {matchLabels: {app: app}}
  template:
    metadata: {labels: {app: app}}
    spec:
      containers:
        - name: app
          image: nginx:1.27
          ports: [{containerPort: 80}]
---
# Task 17
apiVersion: v1
kind: ServiceAccount
metadata: {name: old-ci, namespace: m2-shop}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: old-ci-admin}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects:
  - {kind: ServiceAccount, name: old-ci, namespace: m2-shop}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: backup-agent, namespace: m2-batch}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: backup-agent-admin}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects:
  - {kind: ServiceAccount, name: backup-agent, namespace: m2-batch}
EOF

echo "✅ Mock exam 2 ready. Start the timer: 120 minutes."
