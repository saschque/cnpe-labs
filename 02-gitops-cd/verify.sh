#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
app() { k -n argocd get application "$1" -o jsonpath="$2"; }

section "2.1 Argo CD Application"
eq "guestbook Synced" "Synced" app guestbook '{.status.sync.status}'
eq "guestbook Healthy" "Healthy" app guestbook '{.status.health.status}'
eq "selfHeal aktiv" "true" app guestbook '{.spec.syncPolicy.automated.selfHeal}'

section "2.2 ApplicationSet"
check "ApplicationSet guestbook-envs existiert" k -n argocd get applicationset guestbook-envs
for env in dev staging prod; do
  check "Application guestbook-$env existiert" k -n argocd get application guestbook-$env
done
eq "prod ohne Auto-Sync" "" app guestbook-prod '{.spec.syncPolicy.automated}'
eq "staging replicaCount=2" "2" app guestbook-staging '{.spec.source.helm.parameters[?(@.name=="replicaCount")].value}'

section "2.4 / 2.5 Flux"
eq "Kustomization podinfo Ready" "True" k -n flux-system get kustomization podinfo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
eq "HelmRelease podinfo-helm Ready" "True" k -n podinfo-helm get helmrelease podinfo-helm -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
eq "HelmRelease 2 Replicas" "2" k -n podinfo-helm get deploy podinfo-helm -o jsonpath='{.spec.replicas}'

section "2.6 Broken App"
eq "broken-app Synced" "Synced" app broken-app '{.status.sync.status}'
eq "broken-app Healthy" "Healthy" app broken-app '{.status.health.status}'

section "2.7 Tekton"
check "Task lint-yaml existiert" k -n ci get task lint-yaml
check "Pipeline ci-pipeline existiert" k -n ci get pipeline ci-pipeline
check "Mind. ein erfolgreicher PipelineRun" bash -c \
  "kubectl -n ci get pipelineruns -o jsonpath='{.items[*].status.conditions[0].reason}' | grep -q Succeeded"

section "2.8 Argo Workflows"
check "WorkflowTemplate platform-dag existiert" k -n argo get workflowtemplate platform-dag
eq "CronWorkflow Forbid" "Forbid" k -n argo get cronworkflow nightly-cleanup -o jsonpath='{.spec.concurrencyPolicy}'
check "Mind. ein erfolgreicher Workflow" bash -c \
  "kubectl -n argo get workflows -o jsonpath='{.items[*].status.phase}' | grep -q Succeeded"

section "2.9 Flagger"
check "Canary podinfo existiert" k -n canary-demo get canary podinfo
eq "maxWeight=50" "50" k -n canary-demo get canary podinfo -o jsonpath='{.spec.analysis.maxWeight}'
check "Primary-Deployment erzeugt" k -n canary-demo get deploy podinfo-primary

summary
