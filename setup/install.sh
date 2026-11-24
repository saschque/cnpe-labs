#!/usr/bin/env bash
# Installiert die CNPE-Tools per Helm. Nutzung:
#   ./setup/install.sh argocd flux kyverno
#   ./setup/install.sh all
set -euo pipefail

helm_repo() { helm repo add "$1" "$2" >/dev/null 2>&1 || true; }

install_argocd() {
  helm_repo argo https://argoproj.github.io/argo-helm
  helm repo update argo
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
    --set configs.params."server\.insecure"=true --wait
  echo "Argo CD Admin-Passwort:"
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
    -n gatekeeper-system --create-namespace --wait
}

install_prometheus() {
  helm_repo prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update prometheus-community
  # Sidecar sucht Dashboards in allen Namespaces mit Label grafana_dashboard=1
  helm upgrade --install kps prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
    --set grafana.sidecar.dashboards.searchNamespace=ALL --wait
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
  helm upgrade --install istiod istio/istiod -n istio-system --wait
}

install_linkerd() {
  command -v linkerd >/dev/null || { echo "linkerd CLI fehlt (https://linkerd.io/2/getting-started/)"; return 1; }
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
  # Jaeger v2 (All-in-one, nimmt OTLP direkt an)
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
  echo "OTel Collector wird in Aufgabe 4.5 selbst installiert."
}

ALL=(argocd argo_workflows flux tekton crossplane kyverno gatekeeper prometheus opencost istio flagger jaeger_otel)

[[ $# -eq 0 ]] && { echo "Nutzung: $0 <tool...>|all   Tools: ${ALL[*]} linkerd"; exit 1; }
[[ "$1" == "all" ]] && set -- "${ALL[@]}"

for tool in "$@"; do
  tool="${tool//-/_}"
  echo "==> Installiere $tool"
  "install_$tool"
done
echo "✅ Fertig."
