#!/usr/bin/env bash
# Removes add-ons again to free resources. Usage:
#   ./setup/uninstall.sh argocd prometheus
#   ./setup/uninstall.sh all
set -uo pipefail

helm_rm() {  # <release> <namespace>
  helm uninstall "$1" -n "$2" --wait 2>/dev/null || echo "   (release $1 not found)"
}
ns_rm() { kubectl delete ns "$@" --ignore-not-found --wait=false; }

uninstall_argocd()         { helm_rm argocd argocd; ns_rm argocd; }
uninstall_argo_workflows() { helm_rm argo-workflows argo; ns_rm argo; }
uninstall_flux() {
  if command -v flux >/dev/null; then flux uninstall --silent
  else kubectl delete -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml --ignore-not-found; fi
}
uninstall_tekton() {
  kubectl delete -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml --ignore-not-found
}
uninstall_crossplane()     { helm_rm crossplane crossplane-system; ns_rm crossplane-system; }
uninstall_kyverno() {
  helm_rm kyverno kyverno; ns_rm kyverno
  # webhooks Kyverno registered itself – left over, they would block every API request
  kubectl delete validatingwebhookconfigurations,mutatingwebhookconfigurations \
    -l webhook.kyverno.io/managed-by=kyverno --ignore-not-found
}
uninstall_gatekeeper()     { helm_rm gatekeeper gatekeeper-system; ns_rm gatekeeper-system; }
uninstall_prometheus()     { helm_rm kps monitoring; ns_rm monitoring; }
uninstall_opencost()       { helm_rm opencost opencost; ns_rm opencost; }
uninstall_flagger()        { helm_rm flagger istio-system; }
uninstall_istio()          { helm_rm flagger istio-system; helm_rm istiod istio-system; helm_rm istio-base istio-system; ns_rm istio-system; }
uninstall_linkerd()        { command -v linkerd >/dev/null && linkerd uninstall | kubectl delete -f - --ignore-not-found; }
uninstall_jaeger_otel()    { ns_rm observability; }

ALL=(flagger opencost argocd argo_workflows flux tekton crossplane kyverno gatekeeper prometheus istio jaeger_otel)
[[ $# -eq 0 ]] && { echo "Usage: $0 <tool...>|all   Tools: ${ALL[*]} linkerd"; exit 1; }
[[ "$1" == "all" ]] && set -- "${ALL[@]}"
for tool in "$@"; do
  tool="${tool//-/_}"
  echo "==> Removing $tool"
  "uninstall_$tool"
done
echo "✅ Done. CRDs stay installed (they cost almost nothing). Check: ./setup/resources.sh"
