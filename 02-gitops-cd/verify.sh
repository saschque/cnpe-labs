#!/usr/bin/env bash
source "$(dirname "$0")/../setup/lib.sh"
k() { kubectl "$@"; }
app() { k -n argocd get application "$1" -o jsonpath="$2"; }

section "2.1 Argo CD Application"
eq "guestbook Synced" "Synced" app guestbook '{.status.sync.status}'
eq "guestbook Healthy" "Healthy" app guestbook '{.status.health.status}'
eq "selfHeal enabled" "true" app guestbook '{.spec.syncPolicy.automated.selfHeal}'

section "2.2 ApplicationSet"
check "ApplicationSet guestbook-envs exists" k -n argocd get applicationset guestbook-envs
for env in dev staging prod; do
  check "Application guestbook-$env exists" k -n argocd get application guestbook-$env
done
eq "prod without auto-sync" "" app guestbook-prod '{.spec.syncPolicy.automated}'
eq "staging replicaCount=2" "2" app guestbook-staging '{.spec.source.helm.parameters[?(@.name=="replicaCount")].value}'

section "2.4 / 2.5 Flux"
eq "Kustomization podinfo Ready" "True" k -n flux-system get kustomization podinfo -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
eq "HelmRelease podinfo-helm Ready" "True" k -n podinfo-helm get helmrelease podinfo-helm -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
eq "HelmRelease 2 Replicas" "2" k -n podinfo-helm get deploy podinfo-helm -o jsonpath='{.spec.replicas}'

section "2.6 Broken App"
eq "broken-app Synced" "Synced" app broken-app '{.status.sync.status}'
eq "broken-app Healthy" "Healthy" app broken-app '{.status.health.status}'

section "2.7 Tekton"
check "Task lint-yaml exists" k -n ci get task lint-yaml
check "Pipeline ci-pipeline exists" k -n ci get pipeline ci-pipeline
check "At least one successful PipelineRun" bash -c \
  "kubectl -n ci get pipelineruns -o jsonpath='{.items[*].status.conditions[0].reason}' | grep -q Succeeded"

section "2.8 Argo Workflows"
check "WorkflowTemplate platform-dag exists" k -n argo get workflowtemplate platform-dag
eq "CronWorkflow Forbid" "Forbid" k -n argo get cronworkflow nightly-cleanup -o jsonpath='{.spec.concurrencyPolicy}'
check "At least one successful workflow" bash -c \
  "kubectl -n argo get workflows -o jsonpath='{.items[*].status.phase}' | grep -q Succeeded"

section "2.9 Flagger"
check "Canary podinfo exists" k -n canary-demo get canary podinfo
eq "maxWeight=50" "50" k -n canary-demo get canary podinfo -o jsonpath='{.spec.analysis.maxWeight}'
check "Primary deployment created" k -n canary-demo get deploy podinfo-primary

section "2.10 AppProject"
check "AppProject team-a exists" k -n argocd get appproject team-a
eq "Destination only team-a-*" "team-a-*" k -n argocd get appproject team-a -o jsonpath='{.spec.destinations[0].namespace}'
eq "Only Namespace cluster-scoped" "Namespace" k -n argocd get appproject team-a -o jsonpath='{.spec.clusterResourceWhitelist[*].kind}'
eq "team-a-guestbook Synced" "Synced" app team-a-guestbook '{.status.sync.status}'

section "2.11 ApplicationSet Git directories"
check "Application helm-guestbook created" k -n argocd get application helm-guestbook
check "Application kustomize-guestbook created" k -n argocd get application kustomize-guestbook
check "jsonnet-guestbook excluded" bash -c "! kubectl -n argocd get application jsonnet-guestbook"

section "2.12 Flux Staging"
eq "HPA minReplicas=3" "3" k -n podinfo-staging get hpa podinfo -o jsonpath='{.spec.minReplicas}'
eq "Label env=staging" "staging" k -n podinfo-staging get deploy podinfo -o jsonpath='{.metadata.labels.env}'
eq "dependsOn podinfo" "podinfo" k -n flux-system get kustomization podinfo-staging -o jsonpath='{.spec.dependsOn[0].name}'

section "2.13 Tekton when/finally"
check "Run with skipped approve-prod" bash -c \
  "kubectl -n ci get pipelineruns -o json | jq -e '[.items[] | select(.spec.pipelineRef.name==\"release-gate\") | .status.skippedTasks[]?.name] | index(\"approve-prod\") != null'"
check "finally task notify defined" bash -c "kubectl -n ci get pipeline release-gate -o jsonpath='{.spec.finally[*].name}' | grep -q notify"

section "2.14 Coinflip"
eq "onExit set" "exit-handler" k -n argo get workflowtemplate coinflip -o jsonpath='{.spec.onExit}'
check "At least one successful coinflip workflow" bash -c \
  "kubectl -n argo get wf -o json | jq -e '[.items[] | select(.spec.workflowTemplateRef.name==\"coinflip\" and .status.phase==\"Succeeded\")] | length > 0'"

summary
