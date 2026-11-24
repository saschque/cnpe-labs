# CNPE Labs – Practice exercises for the Certified Cloud Native Platform Engineer

Hands-on exercises for the **CNPE** exam by the Linux Foundation / CNCF.
The exam is **performance-based** (about 15–20 tasks in 120 minutes in a remote Linux
environment). This repo mirrors the five official domains.

| # | Domain | Weight | Folder | Tasks |
|---|--------|--------|--------|-------|
| 1 | Platform Architecture and Infrastructure | 15 % | [`01-platform-architecture`](01-platform-architecture/) | 12 |
| 2 | GitOps and Continuous Delivery | 25 % | [`02-gitops-cd`](02-gitops-cd/) | 14 |
| 3 | Platform APIs and Self-Service Capabilities | 25 % | [`03-platform-apis`](03-platform-apis/) | 12 |
| 4 | Observability and Operations | 20 % | [`04-observability`](04-observability/) | 12 |
| 5 | Security and Policy Enforcement | 15 % | [`05-security-policy`](05-security-policy/) | 13 |

Plus:
- [`mock-exams/`](mock-exams/) – four full mock exams (120 min, 17 tasks, 100 points each)
- [`CHEATSHEET.md`](CHEATSHEET.md) – the most important commands at a glance

> ⚠️ The official curriculum (github.com/cncf/curriculum) is the reference. Check before the
> exam whether the domains or the tool list have changed.

## Tools in the exam environment

Argo CD · Argo Workflows · Crossplane · Flagger · Flux · Gatekeeper/OPA · Grafana ·
Istio · Jaeger · Kyverno · Linkerd · OpenCost · OpenTelemetry · Prometheus · Tekton –
plus `kubectl`, `helm`, `kustomize`, `git`, `jq`, `yq`.

## Quick start

```bash
# 1. Create a local cluster (kind, 1 control plane + 2 workers)
./setup/create-cluster.sh

# 2. Only install the tools you are practicing right now (saves RAM)
./setup/install.sh argocd flux kyverno
./setup/install.sh all          # everything (≥ 16 GB RAM recommended)

# 3. Work through the tasks
cat 01-platform-architecture/README.md

# 4. Check your result
./01-platform-architecture/verify.sh
```

Requirements: Docker, [kind](https://kind.sigs.k8s.io), kubectl, helm, git, jq.
Optional: `argocd`, `flux`, `tkn`, `argo`, `istioctl`, `linkerd`, `crossplane`, `gator` CLIs.

## Structure of each domain

```
0X-domain/
├── README.md        # tasks (scenario, requirements, checks)
├── solutions/       # reference solutions (only look AFTER your own attempt!)
└── verify.sh        # automatic check of your solution
```

## Mock exams

| Exam | Focus | Extra tools |
|------|-------|-------------|
| [Exam 1](mock-exams/exam-1/) | Broad coverage of all domains | – |
| [Exam 2](mock-exams/exam-2/) | Guardrails, self-service, OTel troubleshooting | Jaeger/OTel |
| [Exam 3](mock-exams/exam-3/) | Service mesh, progressive delivery, troubleshooting | Istio, Flagger, Gatekeeper |
| [Exam 4](mock-exams/exam-4/) | Cost, operator operations, audit | OpenCost |

Each exam: `setup.sh` (prepares the scenario) → 120 min timer → `verify.sh` (point-based
scoring, pass mark 66 %) → `SOLUTIONS.md`. Ideally use a fresh cluster for each exam.

## Study strategy

1. **Mind the weights:** GitOps + Platform APIs = 50 % of the points.
2. **Practice navigating the docs:** In the exam you have access to the official docs.
   Bookmark them and practice finding and adapting examples quickly.
3. **Go imperative where possible:** `kubectl create ... --dry-run=client -o yaml` saves time.
4. **Break things:** `04-observability/scenarios/` contains intentionally broken workloads –
   train troubleshooting under time pressure.
5. **Time management:** Skim all tasks first, take the quick wins, flag hard tasks and come
   back to them later.
6. **Context!** Every task names a cluster/namespace – in the exam, always run
   `kubectl config use-context ...` first.

## Progress

- [ ] Domain 1 – Platform architecture
- [ ] Domain 2 – GitOps & CD
- [ ] Domain 3 – Platform APIs
- [ ] Domain 4 – Observability
- [ ] Domain 5 – Security & policy
- [ ] Mock exam 1 ≥ 66 %
- [ ] Mock exam 2 ≥ 66 %
- [ ] Mock exam 3 ≥ 66 %
- [ ] Mock exam 4 ≥ 66 % in < 120 min
