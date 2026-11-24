#!/usr/bin/env bash
# Bereitet die Mock-Exam-Umgebung vor. Vor dem Starten des Timers ausführen.
set -euo pipefail

kubectl create ns mx-team-red --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns mx-incident --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns ci --dry-run=client -o yaml | kubectl apply -f -

# Aufgabe 2/3/17: Workloads
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: mx-team-red}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
        - name: api
          image: nginx:1.27
          resources: {requests: {cpu: 50m, memory: 64Mi}, limits: {memory: 128Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: db, namespace: mx-team-red}
spec:
  replicas: 1
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers:
        - name: db
          image: busybox
          command: ["sleep", "infinity"]
          ports: [{containerPort: 5432}]
          resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 32Mi}}
EOF

# Aufgabe 5: kaputte Application
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: mx-broken, namespace: argocd}
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: mainn
    path: helm-guestbook
    helm:
      valueFiles: ["values-prod.yaml"]
  destination:
    server: https://kubernetes.default.svc
    namespace: mx-broken
  syncPolicy:
    automated: {prune: true}
    syncOptions: ["CreateNamespace=true"]
EOF

# Aufgabe 10: Function, RBAC, XRD
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-patch-and-transform}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane-compose-configmaps
  labels: {rbac.crossplane.io/aggregate-to-crossplane: "true"}
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["*"]
---
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata: {name: buckets.storage.example.org}
spec:
  scope: Namespaced
  group: storage.example.org
  names: {kind: Bucket, plural: buckets}
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
              required: [sizeGB]
              properties:
                sizeGB: {type: integer}
EOF

# Aufgabe 13: kaputte App
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata: {name: checkout-config, namespace: mx-incident}
data:
  PAYMENT_URL: http://payments
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: checkout, namespace: mx-incident}
spec:
  replicas: 2
  selector: {matchLabels: {app: checkout}}
  template:
    metadata: {labels: {app: checkout, version: v2}}
    spec:
      containers:
        - name: checkout
          image: nginx:1.27
          envFrom:
            - configMapRef: {name: checkout-cfg}
          ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: checkout, namespace: mx-incident}
spec:
  selector: {app: checkout, version: v1}
  ports: [{port: 80, targetPort: 80}]
EOF

echo "✅ Mock-Exam-Umgebung bereit. Timer starten: 120 Minuten."
