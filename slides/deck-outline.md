# Slide deck outline — Custom Workbench Images Demo

Style: title + bullets; Red Hat–neutral (#CC0000 accent, #1A1A1A text, white background).

---

## Slide 1 — Title
**Custom Workbench Images for OpenShift AI**
- Jupyter workbench + OpenCode CLI
- 45-minute session

Speaker notes: Introduce yourself; audience is platform + data science practitioners on RHOAI 3.4.

---

## Slide 2 — Agenda
- OpenShift AI tour (10 min)
- Custom images + CI (10 min)
- Live demo (18 min)
- Wrap-up + Q&A (7 min)

---

## Slide 3 — Who this is for
- Platform engineers registering notebook images
- Data scientists who need consistent dev environments
- Prerequisites: RHOAI 3.4, cluster admin for ImageStream (or BYON import)

---

## Slide 4 — OpenShift AI in one diagram
- DataScienceCluster (operators)
- Data Science Projects (tenancy)
- Workbenches, model serving, pipelines

Speaker notes: [SCREENSHOT: dashboard home]

---

## Slide 5 — Data Science Projects
- Namespace + dashboard visibility
- Shared connections (S3, DB)
- Team collaboration boundary

---

## Slide 6 — Workbenches
- JupyterLab and VS Code options
- PVC for persistent `/opt/app-root/src`
- Stock images vs bring-your-own

---

## Slide 7 — Connected resources
- PVCs, Secrets, ConfigMaps
- Git integration from JupyterLab
- Hardware profiles (CPU/GPU)

---

## Slide 8 — Why customize an image?
- Reproducible dependencies across the team
- CLI tools, system packages, pinned versions
- Same stack in workbench and automation

---

## Slide 9 — Extension patterns
- `pip install` in notebook (quick, not reproducible)
- Extend base image in Containerfile (recommended)
- Separate runtime image for pipelines

---

## Slide 10 — Build + GitOps pipeline
- Source push → Tekton → Quay (`:<commit-sha>`) → ImageStream import
- Pipeline commits to **manifests repo** (`imageTag` bump)
- Argo CD syncs Helm chart

Speaker notes: Two-repo model; webhook on source repo only.

---

## Slide 11 — Dev loop in the workbench
- Both repos cloned to `/opt/app-root/src/`
- Edit Containerfile in source repo, commit, push
- Stop/start workbench after Argo CD sync

---

## Slide 12 — Pipelines: build vs run
- **Build** images: OpenShift Pipelines / Tekton (or podman locally)
- **Run** ML steps: Data Science Pipelines (Kubeflow)
- KFP uses pre-built runtime `base_image`

---

## Slide 13 — Dashboard registration
- Settings → Notebook images
- Custom version tag `1.0` (not platform `3.4`)
- `opendatahub.io/workbench-image-recommended: true`
- `opendatahub.io/notebook-build-commit` must match workbench selection

Speaker notes: [SCREENSHOT: notebook images settings]

---

## Slide 14 — Demo: what we built
- Custom Jupyter Data Science image
- OpenCode CLI in terminal
- Sample Python app for agent demo
- Optional KFP verify pipeline

---

## Slide 15 — LIVE DEMO
- (minimal slide — hand off to cluster)

---

## Slide 16 — OpenCode CLI
- `opencode run` for non-interactive use
- Provider auth via env or `opencode auth`
- Agent for code explanation and refactors

---

## Slide 17 — Operational concerns
- Pin base image and tool versions
- Scan images for CVEs
- Air-gap: vendor OpenCode binary in repo
- Rebuild on dependency updates

---

## Slide 18 — When not to customize
- One-off `pip install` is enough
- Short workshops with stock image
- Cost of maintaining image > benefit

---

## Slide 19 — Runtime images for pipelines
- `Containerfile.runtime` without Jupyter
- Same packages as workbench where possible
- Register runtime in pipeline component `base_image`

---

## Slide 20 — Summary
1. Extend stock RHOAI image with a thin Containerfile
2. Push to Quay; register via ImageStream
3. Develop from git in the workbench; use OpenCode in the terminal

---

## Slide 21 — Links
- Source: [my-custom-workbench](https://github.com/gmodzelewski/my-custom-workbench)
- Manifests: [my-custom-workbench-manifests](https://github.com/gmodzelewski/my-custom-workbench-manifests)
- [OpenCode CLI](https://opencode.ai/docs/cli)
- [RHOAI — managing notebook images](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/)

---

## Slide 22 — Q&A

Speaker notes: Offer presenter runbook and manifests path in repo.
