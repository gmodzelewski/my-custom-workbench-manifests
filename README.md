# my-custom-workbench-manifests

Helm chart, GitOps, Tekton CI, and demo assets for the **Custom Workbench (OpenCode)** on Red Hat OpenShift AI 3.4.

Image source code (Containerfiles) lives in the companion repo **[my-custom-workbench](https://github.com/gmodzelewski/my-custom-workbench)**.

## Repositories

| Repo | Purpose |
|------|---------|
| [my-custom-workbench](https://github.com/gmodzelewski/my-custom-workbench) | `Containerfile`, `Containerfile.runtime`, `demo/sample-app/` |
| **this repo** | Helm chart, Argo CD ApplicationSet, Tekton pipeline, scripts, slides |

At workbench start, both repos are cloned to `/opt/app-root/src/my-custom-workbench` and `/opt/app-root/src/my-custom-workbench-manifests`.

## Demo workflow (GitOps loop)

```
Edit Containerfile → push source repo
        ↓
GitHub webhook → Tekton PipelineRun
        ↓
buildah push quay.io/.../custom-workbench-opencode:<short-sha>
        ↓
oc import-image + git commit to this repo (values.yaml imageTag)
        ↓
Argo CD sync → ImageStream + Notebook CR update
        ↓
Stop/restart workbench → new image running
```

See [gitops/README.md](gitops/README.md) for bootstrap, secrets, and webhook setup.

## Quick start

### Deploy with GitOps

```bash
oc apply -f gitops/applicationset.yaml
```

### Deploy with Helm directly

```bash
helm template custom-workbench charts/custom-workbench/
helm upgrade --install custom-workbench charts/custom-workbench/ -n redhat-ods-applications
```

Create pipeline secrets first (see [gitops/README.md](gitops/README.md)).

### Local image build (from sibling source checkout)

```bash
# Clone both repos side by side, then from this repo:
./scripts/build.sh
./scripts/verify-image.sh
./scripts/push.sh
```

Override source path: `SOURCE_ROOT=/path/to/my-custom-workbench ./scripts/build.sh`

## What's in this repo

| Path | Purpose |
|------|---------|
| `charts/custom-workbench/` | Helm chart — ImageStreams, Tekton CI/CD + GitOps bump, demo Notebook |
| `gitops/applicationset.yaml` | Argo CD ApplicationSet (tracks this repo) |
| `scripts/` | Local podman build/push/verify/import helpers |
| `pipelines/` | Optional KFP verify pipeline for runtime image |
| `docs/presenter-runbook.md` | 45-minute session guide |
| `slides/` | Deck outline + `generate_deck.py` → PPTX |

## Configuration

Edit [scripts/env.defaults.sh](scripts/env.defaults.sh) for Quay org, image tag (local builds), and repo URLs.

Cluster Tekton builds tag images with the **7-character source commit SHA** and update `charts/custom-workbench/values.yaml` automatically.

## Presentation

```bash
pip install -r requirements-slides.txt
python slides/generate_deck.py
# → slides/custom-workbench-demo.pptx
```

Presenter guide: [docs/presenter-runbook.md](docs/presenter-runbook.md).

## License

See [LICENSE](LICENSE).
