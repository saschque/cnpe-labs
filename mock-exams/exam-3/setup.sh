#!/usr/bin/env bash
# Prepares mock exam 3. Run before starting the timer.
set -euo pipefail

for ns in m3-app m3-db m3-mon m3-incident m3-outside m3-restricted ci; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
for ns in m3-canary m3-mesh; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label ns "$ns" istio-injection=enabled --overwrite
done

kubectl apply -f - <<'EOF'
# Task 1 + 3
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: m3-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
        - name: web
          image: registry.k8s.io/hpa-example
          resources: {requests: {cpu: 50m, memory: 32Mi}}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: postgres, namespace: m3-db}
spec:
  selector: {matchLabels: {app: postgres}}
  template:
    metadata: {labels: {app: postgres}}
    spec:
      containers:
        - name: pg
          image: registry.k8s.io/pause:3.10
          ports: [{containerPort: 5432}]
---
# Task 5: broken Flux resources
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata: {name: m3-podinfo, namespace: flux-system}
spec:
  interval: 1m
  url: https://github.com/stefanprodan/podinfo
  ref: {branch: main}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: {name: m3-podinfo, namespace: flux-system}
spec:
  interval: 2m
  path: ./kustomise
  prune: true
  targetNamespace: m3-flux
  sourceRef: {kind: GitRepository, name: m3-podinfo}
---
# Task 8
apiVersion: apps/v1
kind: Deployment
metadata: {name: podinfo, namespace: m3-canary}
spec:
  replicas: 1
  selector: {matchLabels: {app: podinfo}}
  template:
    metadata: {labels: {app: podinfo}}
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.7.0
          ports: [{name: http, containerPort: 9898}]
---
# Task 10: function + RBAC
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata: {name: function-patch-and-transform}
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.8.2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: m3-crossplane-workloads
  labels: {rbac.crossplane.io/aggregate-to-crossplane: "true"}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["*"]
---
# Task 12: ServiceAccount for the self-service workflow
apiVersion: v1
kind: ServiceAccount
metadata: {name: m3-provisioner, namespace: argo}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: m3-provisioner}
rules:
  - apiGroups: ["platform.m3.io"]
    resources: ["webservices"]
    verbs: ["create", "get", "list", "watch"]
  - apiGroups: ["argoproj.io"]
    resources: ["workflowtaskresults"]
    verbs: ["create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: m3-provisioner}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: m3-provisioner}
subjects:
  - {kind: ServiceAccount, name: m3-provisioner, namespace: argo}
---
# Task 13: two errors in the ServiceMonitor
apiVersion: apps/v1
kind: Deployment
metadata: {name: podinfo, namespace: m3-mon}
spec:
  selector: {matchLabels: {app: podinfo}}
  template:
    metadata: {labels: {app: podinfo}}
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.7.0
          ports: [{containerPort: 9898}]
---
apiVersion: v1
kind: Service
metadata: {name: podinfo, namespace: m3-mon, labels: {app: podinfo}}
spec:
  selector: {app: podinfo}
  ports: [{name: web, port: 9898}]
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata: {name: podinfo, namespace: m3-mon}
spec:
  selector: {matchLabels: {app: pod-info}}
  endpoints:
    - {port: http, path: /metrics, interval: 15s}
---
# Task 15
apiVersion: v1
kind: ConfigMap
metadata: {name: worker-config, namespace: m3-incident}
data:
  QUEUE: jobs
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: worker, namespace: m3-incident}
spec:
  selector: {matchLabels: {app: worker}}
  template:
    metadata: {labels: {app: worker}}
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo consuming $QUEUE_NAME; sleep 3600"]
          env:
            - name: QUEUE_NAME
              valueFrom: {configMapKeyRef: {name: worker-config, key: QUEUE_NAME}}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-all-egress, namespace: m3-incident}
spec:
  podSelector: {}
  policyTypes: [Egress]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend, namespace: m3-incident}
spec:
  selector: {matchLabels: {app: frontend}}
  template:
    metadata: {labels: {app: frontend}}
    spec:
      containers:
        - name: frontend
          image: busybox:1.36
          command: ["sh", "-c", "while true; do nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 || { echo 'cannot resolve backend'; exit 1; }; sleep 10; done"]
---
# Task 16
apiVersion: v1
kind: ServiceAccount
metadata: {name: httpbin, namespace: m3-mesh}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: httpbin, namespace: m3-mesh}
spec:
  selector: {matchLabels: {app: httpbin}}
  template:
    metadata: {labels: {app: httpbin}}
    spec:
      serviceAccountName: httpbin
      containers:
        - {name: httpbin, image: kennethreitz/httpbin, ports: [{containerPort: 80}]}
---
apiVersion: v1
kind: Service
metadata: {name: httpbin, namespace: m3-mesh}
spec:
  selector: {app: httpbin}
  ports: [{name: http, port: 80}]
EOF

for ns in m3-mesh m3-outside; do
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata: {name: sleep, namespace: $ns}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: sleep, namespace: $ns}
spec:
  selector: {matchLabels: {app: sleep}}
  template:
    metadata: {labels: {app: sleep}}
    spec:
      serviceAccountName: sleep
      containers:
        - {name: sleep, image: curlimages/curl, command: ["sleep", "infinity"]}
EOF
done

echo "✅ Mock exam 3 ready. Start the timer: 120 minutes."
