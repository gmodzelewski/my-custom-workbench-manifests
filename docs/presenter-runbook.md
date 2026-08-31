# Presenter runbook — Custom Workbench Images (45 min)

**Audience:** Platform engineers and data scientists using Red Hat OpenShift AI (RHOAI) 3.4.

**Red thread:** Two-repo GitOps demo — edit image source, push, CI builds, manifests repo updates, Argo CD deploys, restart workbench to see the change.

## Repositories

| Repo | Role |
|------|------|
| [my-custom-workbench](https://github.com/gmodzelewski/my-custom-workbench) | Containerfiles + demo Python module |
| [my-custom-workbench-manifests](https://github.com/gmodzelewski/my-custom-workbench-manifests) | Helm, Tekton, GitOps, slides, this runbook |

Both are cloned into the workbench PVC at startup.

## 45-minute run-of-show

| Block | Min | Format | Content |
|-------|-----|--------|---------|
| Title + outcomes | 2 | Slides | Build, register, GitOps loop |
| OpenShift AI platform map | 8 | Slides | DSC, projects, workbenches, serving, pipelines |
| Workbench images deep dive | 5 | Slides | Stock vs BYON, ImageStream annotations |
| Git → CI → GitOps loop | 5 | Slides | Source push → Tekton → manifests commit → Argo CD |
| Pipelines: build vs run | 2 | Slides | OpenShift Pipelines builds images; KFP runs ML steps |
| Demo transition | 2 | Slides | Architecture diagram |
| **Live demo** | 18 | Cluster + terminal | Two repos → push → pipeline → restart workbench |
| Best practices + resources | 4 | Slides | Pinning, scanning, air-gap |
| Q&A buffer | 1 | — | Absorb overruns |

**Do not wait on camera:** image builds (5–15 min), pipeline server first deploy, workbench cold start.

## Live demo script

### Slides-only segments

Acts 1–5 and wrap-up are slides.

### Live segment (18 min)

1. **Repo tour (3 min)** — In workbench: `/opt/app-root/src/my-custom-workbench/Containerfile` and `/opt/app-root/src/my-custom-workbench-manifests/charts/custom-workbench/values.yaml`.
2. **Dashboard (3 min)** — Settings → Notebook images → **Custom workbench (OpenCode)** with current commit SHA tag.
3. **Workbench (2 min)** — Project `custom-workbench-demo`; open running workbench (pre-started).
4. **GitOps loop (8 min)**:
   - Edit `Containerfile` (visible label or env var)
   - Commit + push **source repo**
   - Show PipelineRun in OpenShift Pipelines (`tkn pipelinerun list -n redhat-ods-applications`)
   - Show manifests repo received auto-commit with new `imageTag`
   - Show Argo CD Application synced
   - **Stop and restart** workbench; verify change (e.g. `opencode --version` or label)
5. **Terminal demo (2 min)**:

   ```bash
   opencode --version
   cd /opt/app-root/src/my-custom-workbench/demo/sample-app
   python -c "from pricing import format_receipt; print(format_receipt(100, 'gold'))"
   ```

### Backup if workbench is slow

- Screenshot: notebook images list with SHA tag
- Screenshot: Argo CD sync status
- Screenshot: completed PipelineRun

## Pre-stage checklist (day before)

- [ ] `helm template custom-workbench charts/custom-workbench/` renders without errors
- [ ] Argo CD Application `custom-workbench-in-cluster` is **Synced** and **Healthy**
- [ ] Pipeline secrets exist (`quay-push-credentials`, `github-pat` with **push to manifests repo**, `github-webhook-secret`)
- [ ] GitHub webhook on **source repo only** → EventListener Route
- [ ] ImageStream tag matching `values.yaml` `global.imageTag` exists in Quay
- [ ] Workbench **Running** in `custom-workbench-demo`; both repos visible under `/opt/app-root/src/`
- [ ] OpenCode LLM auth configured (never commit keys)
- [ ] Slides: `slides/custom-workbench-demo.pptx` reviewed
- [ ] Fill cluster-specific URLs below

## Cluster-specific values

| Item | Value |
|------|-------|
| Cluster API | `https://api.____________` |
| RHOAI dashboard | `https://____________` |
| Quay workbench image | `quay.io/modzelewski/custom-workbench-opencode:<sha>` |
| Demo namespace | `custom-workbench-demo` |
| EventListener Route | `https://____________` |
| OpenCode model flag | `-m ____________` |

## OpenCode auth (pre-stage)

OpenCode loads API keys from environment variables or `~/.local/share/opencode/auth.json`. For the demo workbench:

1. Create a Secret with provider keys (see [OpenCode CLI docs](https://opencode.ai/docs/cli)).
2. Mount as env vars or files; **do not** commit credentials.
3. Rehearse `opencode run` once with the exact `-m` flag you will use on stage.

Avoid the OpenCode **TUI** in the Jupyter web terminal; use `opencode run` only.

## GitOps demo loop (on-camera)

1. Edit `Containerfile` in `/opt/app-root/src/my-custom-workbench`.
2. Commit and push to **source repo** `main`.
3. Watch PipelineRun: build → Quay push → import-image → **git commit to manifests repo**.
4. Watch Argo CD sync the Application.
5. **Stop and start** workbench in RHOAI dashboard — running pod does not hot-reload.

Pushing to the manifests repo manually deploys chart changes but does not rebuild the image.

## Teardown (after session)

```bash
helm uninstall custom-workbench -n redhat-ods-applications
oc delete application custom-workbench-in-cluster -n openshift-gitops --ignore-not-found
```

## Risks

| Risk | Mitigation |
|------|------------|
| Workbench cold start | Pre-start; keep screenshots |
| Build on camera | Pre-run one loop; show PipelineRun list |
| LLM provider down | Pre-record terminal output |
| Tekton git push fails | Verify PAT push scope on manifests repo |
| Argo CD out of sync | `oc get application -n openshift-gitops` before demo |
| Pipeline loop | Webhook on source repo only (CEL filter) |
