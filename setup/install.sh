#!/usr/bin/env bash
# Installs the CNPE tools via Helm. Usage:
#   ./setup/install.sh argocd flux kyverno
#   ./setup/install.sh all
set -euo pipefail

# Lite mode (smaller footprint): LITE=1 ./setup/install.sh ...
# Defaults to on when the cluster has a single node (./setup/create-cluster.sh --lite).
if [[ -z "${LITE:-}" ]]; then
  [[ $(kubectl get nodes --no-headers 2>/dev/null | wc -l) -eq 1 ]] && LITE=1 || LITE=0
fi
lite() { [[ "$LITE" == "1" ]] && printf '%s\n' "$@"; return 0; }   # prints extra helm args in lite mode
[[ "$LITE" == "1" ]] && echo "ℹ️  Lite mode: reduced replicas and resource requests"

helm_repo() { helm repo add "$1" "$2" >/dev/null 2>&1 || true; }

install_argocd() {
  helm_repo argo https://argoproj.github.io/argo-helm
  helm repo update argo
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
    --set configs.params."server\.insecure"=true \
    $(lite --set=dex.enabled=false --set=notifications.enabled=false \
      --set=controller.resources.requests.cpu=100m --set=controller.resources.requests.memory=256Mi \
      --set=repoServer.resources.requests.cpu=50m --set=repoServer.resources.requests.memory=128Mi) \
    --wait
  echo "Argo CD admin password:"
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
}

install_argo_workflows() {
  helm_repo argo https://argoproj.github.io/argo-helm
  helm repo update argo
  helm upgrade --install argo-workflows argo/argo-workflows -n argo --create-namespace \
    --set server.authModes='{server}' --set workflow.serviceAccount.create=true --wait
}

install_flux() {
  if command -v flux >/dev/null; then
    flux install
  else
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
  fi
}

install_tekton() {
  kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
  kubectl -n tekton-pipelines wait --for=condition=Available deploy --all --timeout=300s
}

install_crossplane() {
  helm_repo crossplane-stable https://charts.crossplane.io/stable
  helm repo update crossplane-stable
  helm upgrade --install crossplane crossplane-stable/crossplane \
    -n crossplane-system --create-namespace --wait
}

install_kyverno() {
  helm_repo kyverno https://kyverno.github.io/kyverno/
  helm repo update kyverno
  helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --wait
}

install_gatekeeper() {
  helm_repo gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
  helm repo update gatekeeper
  helm upgrade --install gatekeeper gatekeeper/gatekeeper \
    -n gatekeeper-system --create-namespace \
    $(lite --set=replicas=1 --set=controllerManager.resources.requests.cpu=50m \
      --set=controllerManager.resources.requests.memory=128Mi --set=audit.resources.requests.cpu=50m \
      --set=audit.resources.requests.memory=128Mi) \
    --wait
}

install_prometheus() {
  helm_repo prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update prometheus-community
  # the sidecar picks up dashboards in all namespaces with label grafana_dashboard=1
  helm upgrade --install kps prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
    --set grafana.sidecar.dashboards.searchNamespace=ALL \
    $(lite --set=alertmanager.enabled=false --set=prometheus.prometheusSpec.retention=6h \
      --set=prometheus.prometheusSpec.scrapeInterval=60s \
      --set=prometheus.prometheusSpec.resources.requests.memory=256Mi \
      --set=kubeEtcd.enabled=false --set=kubeControllerManager.enabled=false \
      --set=kubeScheduler.enabled=false --set=kubeProxy.enabled=false) \
    --wait
  echo "Grafana: admin / $(kubectl -n monitoring get secret kps-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
}

install_opencost() {
  helm_repo opencost https://opencost.github.io/opencost-helm-chart
  helm repo update opencost
  helm upgrade --install opencost opencost/opencost -n opencost --create-namespace \
    --set opencost.prometheus.internal.serviceName=kps-kube-prometheus-stack-prometheus \
    --set opencost.prometheus.internal.namespaceName=monitoring \
    --set opencost.prometheus.internal.port=9090 --wait
}

install_istio() {
  helm_repo istio https://istio-release.storage.googleapis.com/charts
  helm repo update istio
  helm upgrade --install istio-base istio/base -n istio-system --create-namespace --wait
  helm upgrade --install istiod istio/istiod -n istio-system \
    $(lite --set=pilot.resources.requests.cpu=100m --set=pilot.resources.requests.memory=256Mi \
      --set=pilot.autoscaleEnabled=false --set=global.proxy.resources.requests.cpu=10m \
      --set=global.proxy.resources.requests.memory=40Mi) \
    --wait
}

install_linkerd() {
  command -v linkerd >/dev/null || { echo "linkerd CLI missing (https://linkerd.io/2/getting-started/)"; return 1; }
  linkerd install --crds | kubectl apply -f -
  linkerd install | kubectl apply -f -
  linkerd check
}

install_flagger() {
  helm_repo flagger https://flagger.app
  helm repo update flagger
  kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
  helm upgrade --install flagger flagger/flagger -n istio-system \
    --set meshProvider=istio \
    --set metricsServer=http://kps-kube-prometheus-stack-prometheus.monitoring:9090 --wait
}

install_jaeger_otel() {
  helm_repo open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
  helm repo update open-telemetry
  kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
  # Jaeger v2 (all-in-one, accepts OTLP directly)
  kubectl -n observability apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: jaeger, labels: {app: jaeger}}
spec:
  selector: {matchLabels: {app: jaeger}}
  template:
    metadata: {labels: {app: jaeger}}
    spec:
      containers:
        - name: jaeger
          image: jaegertracing/jaeger:latest
          ports: [{containerPort: 16686}, {containerPort: 4317}, {containerPort: 4318}]
---
apiVersion: v1
kind: Service
metadata: {name: jaeger}
spec:
  selector: {app: jaeger}
  ports:
    - {name: ui, port: 16686}
    - {name: otlp-grpc, port: 4317}
    - {name: otlp-http, port: 4318}
EOF
  echo "You install the OTel Collector yourself in task 4.5."
}

ALL=(argocd argo_workflows flux tekton crossplane kyverno gatekeeper prometheus opencost istio flagger jaeger_otel)

[[ $# -eq 0 ]] && { echo "Usage: $0 <tool...>|all   Tools: ${ALL[*]} linkerd"; exit 1; }
[[ "$1" == "all" ]] && set -- "${ALL[@]}"

for tool in "$@"; do
  tool="${tool//-/_}"
  echo "==> Installing $tool"
  "install_$tool"
done
echo "✅ Done."
