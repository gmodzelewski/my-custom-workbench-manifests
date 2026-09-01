# GitOps — custom workbench (OpenShift GitOps / Argo CD)

Deploy the custom workbench stack from the Helm chart in **[my-custom-workbench-manifests](https://github.com/gmodzelewski/my-custom-workbench-manifests)** using an Argo CD ApplicationSet.

Image source code lives in **[my-custom-workbench](https://github.com/gmodzelewski/my-custom-workbench)** (Containerfiles only).

## Prerequisites

- OpenShift cluster with **Red Hat OpenShift AI (RHOAI) 3.4**
- **OpenShift Pipelines** operator (`oc get csv -n openshift-operators | grep openshift-pipelines`)
- **OpenShift GitOps** operator (`oc get csv -n openshift-operators | grep openshift-gitops`)
- Quay repositories for `custom-workbench-opencode` and `custom-workbench-opencode-runtime`
- GitHub PAT with **read** access to the source repo and **push** access to this manifests repo
- GitHub webhook on the **source repo only** (see below)

## Bootstrap

1. Install OpenShift GitOps if not already present (OperatorHub → OpenShift GitOps).

2. Apply the ApplicationSet:

   ```bash
   oc apply -f gitops/applicationset.yaml
   ```

3. Confirm in the Argo CD UI or with `oc`:

   ```bash
   oc get applicationsets.argoproj.io -n openshift-gitops
   oc get applications.argoproj.io -n openshift-gitops
   ```

   **Where to look in the UI:** Open the **Cluster Argo CD** console link (OpenShift GitOps → Argo CD). The ApplicationSet controller creates an **Application** named `custom-workbench-in-cluster` — look under **Applications** in the left sidebar. ApplicationSets appear under **Settings → ApplicationSets** (not in the main Applications list).

   **RBAC note:** OpenShift GitOps defaults to `cluster-admins` only for the Argo CD `admin` role. Other users need entries in the `argocd-rbac-cm` ConfigMap in `openshift-gitops` to view or sync applications.

The chart deploys resources into multiple namespaces (`redhat-ods-applications`, `custom-workbench-demo`).

**Multi-namespace RBAC:** OpenShift GitOps grants the application controller `admin` in the Application **destination** namespace (`redhat-ods-applications`) automatically. For the workbench namespace (`custom-workbench-demo`), the chart labels the Namespace with `argocd.argoproj.io/managed-by: openshift-gitops` so the GitOps operator creates the required RoleBinding. If the namespace already exists without that label:

```bash
oc label namespace custom-workbench-demo argocd.argoproj.io/managed-by=openshift-gitops --overwrite
```

**Argo CD OutOfSync on Notebook / pipeline ServiceAccount:** The ApplicationSet sets `ignoreDifferences` for fields managed by RHOAI (oauth proxy sidecar, CA bundles, platform volumes, pod template metadata such as `/dev/fuse`, initContainer normalization) and OpenShift (dockercfg `imagePullSecrets` on ServiceAccounts). Argo still **applies** Helm changes to those paths on sync; it only skips drift detection there. Re-apply the ApplicationSet after pulling chart changes:

```bash
oc apply -f gitops/applicationset.yaml
```

The ApplicationSet controller updates the generated Application; Argo should then show **Synced** for those resources.

## Secrets (lab vs production)

By default `secrets.create: false` in `charts/custom-workbench/values.yaml`. Create secrets manually before the Tekton pipeline can run:

| Secret | Type | Keys | Used by |
|--------|------|------|---------|
| `quay-push-credentials` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Tekton buildah push to Quay |
| `internal-registry-pull` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Pull RHOAI notebook base from internal registry |
| `redhat-registry-pull` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Pull runtime base from `registry.redhat.io` |
| `tekton-docker-config` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Merged auths for Tekton buildah (bootstrap script) |
| `github-pat` | `kubernetes.io/basic-auth` | `username`, `password` | Tekton git push to manifests repo |
| `workbench-git-credentials` | `Opaque` | `.git-credentials`, `.gitconfig` | Workbench git push/clone (workbench namespace) |
| `workbench-registry-auth` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | In-workbench `podman build` pulls from `registry.redhat.io` |
| `github-webhook-secret` | `Opaque` | `WebHookSecretKey` | EventListener GitHub validation |

```bash
oc create secret docker-registry quay-push-credentials \
  --docker-server=quay.io \
  --docker-username=<robot> \
  --docker-password=<token> \
  -n redhat-ods-applications

oc create secret generic github-pat \
  --from-literal=username=git \
  --from-literal=password=<github-pat-with-push-to-manifests> \
  -n redhat-ods-applications

oc create secret generic github-webhook-secret \
  --from-literal=WebHookSecretKey=<random-string> \
  -n redhat-ods-applications

# Workbench git credentials (from github-pat; not stored in Git)
./scripts/bootstrap-workbench-git-credentials.sh

# In-workbench podman: registry.redhat.io + internal registry pull auths
./scripts/bootstrap-workbench-registry-auth.sh

# Tekton buildah: merge Quay + registry pull credentials (required for webhook builds)
./scripts/bootstrap-tekton-docker-config.sh
./scripts/configure-github-webhook.sh
```

After bootstrap, restart the workbench if it was already running so the pod mounts the secret.

The clone-repos init writes credentials, then clones `my-custom-workbench` and `my-custom-workbench-manifests` onto the PVC. A leftover directory **without** `.git` is removed and replaced (those two folders only). Existing clones are `git pull --ff-only`. Jupyter home `/opt/app-root/src` is not itself a git repo.

## Workbench Podman (cluster-admin, one-time)

OpenShift sets the **pod UID** (Notebook `runAsUser: 1001` + this SCC). It does **not** write `/etc/subuid`. Nested rootless Podman would need that file plus `newuidmap`; the workbench image instead uses **`userns=host`** and `BUILDAH_ISOLATION=chroot` so Podman never calls `newuidmap`.

Grant SCC **`custom-workbench-podman`** (UID **1001**). The SCC is **cluster-scoped** — Argo CD cannot create or patch it. Run once as cluster-admin:

```bash
./scripts/bootstrap-workbench-podman-scc.sh
```

This applies `gitops/custom-workbench-podman-scc.yaml` and grants the SCC to the workbench ServiceAccount (`oc adm policy add-scc-to-user`). Custom SCCs do not get a `system:openshift:scc:*` ClusterRole, so a RoleBinding does not work.

**Security model:** The workbench pod runs as non-root UID **1001** with `allowPrivilegeEscalation: false`. Storage uses **`vfs`** on the PVC. **Tekton is the production build path.** In-workbench `podman build` cannot run `RUN` steps: Buildah 5.8.2 calls `setgroups()` and CRI-O gives UID 1001 an empty capability set.

If `podman` fails with `mkdir .../containers/storage/libpod: permission denied`, the PVC dir is leftover **root-owned** storage. As cluster-admin:

```bash
./scripts/fix-workbench-podman-storage.sh
```

The Notebook spec sets `runAsUser` / `fsGroup` **1001** (`fsGroupChangePolicy: OnRootMismatch`). Restart the workbench from the RHOAI dashboard after bootstrap.

For `podman build`, bootstrap registry auth so pulls from `registry.redhat.io` work:

```bash
./scripts/bootstrap-workbench-registry-auth.sh
```

Restart the workbench so the init container writes `auth.json` onto the PVC. Or in a running terminal:

```bash
mkdir -p ~/.config/containers
oc get secret workbench-registry-auth -n custom-workbench-demo \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > ~/.config/containers/auth.json
chmod 600 ~/.config/containers/auth.json
export REGISTRY_AUTH_FILE=~/.config/containers/auth.json
```

```bash
podman --version
podman info | rg -i 'graphRoot|driver|userns'
```

In-workbench `podman build -f Containerfile .` will fail on `RUN` (`setgroups` EPERM). Use Tekton.

**Lab/demo:** copy `charts/custom-workbench/values-lab.yaml.example` to `values-lab.yaml` (gitignored), fill credentials, and add to Argo CD `helm.valueFiles`.

**Never commit real credentials.**

## GitHub webhook (source repo only)

Configure the webhook on **`my-custom-workbench`**, not on this manifests repo. The EventListener CEL filter accepts pushes to the source repo `main` branch only — this prevents pipeline loops when Tekton commits image tag bumps here.

After sync, get the EventListener Route URL:

```bash
oc get route el-custom-workbench-opencode \
  -n redhat-ods-applications \
  -o jsonpath='https://{.spec.host}{"\n"}'
```

In GitHub → **my-custom-workbench** → Settings → Webhooks → Add:

- Payload URL: Route URL above
- Content type: `application/json`
- Secret: **required** — same value as `WebHookSecretKey` in `github-webhook-secret` (see below)
- Events: **Just the push event**
- Branch: `main`

If the Secret field is left blank on GitHub, deliveries still return **202** from the EventListener, but the Tekton **GitHub interceptor rejects the payload** (`no X-Hub-Signature-256 header set`) and **no PipelineRun is created**.

Verify the cluster secret matches what you typed in GitHub:

```bash
oc get secret github-webhook-secret -n redhat-ods-applications \
  -o jsonpath='{.data.WebHookSecretKey}' | base64 -d; echo
```

Or sync automatically with the GitHub CLI (requires `gh auth login`):

```bash
./scripts/configure-github-webhook.sh
gh api repos/gmodzelewski/my-custom-workbench/hooks --jq '.[] | {url: .config.url, has_secret: (.config.secret != null)}'
```

The second command must show `has_secret: true`. If it shows `false`, pushes will return 202 but no PipelineRun is created.

## Demo GitOps loop

1. Edit `Containerfile` in **my-custom-workbench**, push to `main`.
2. Webhook → Tekton PipelineRun: build image tagged with **7-char commit SHA**, push to Quay, `oc import-image`.
3. Pipeline commits to **this repo**, updating `global.imageTag` and `global.notebookBuildCommit` in `values.yaml`.
4. Argo CD auto-syncs the Helm chart.
5. **Stop and restart** the workbench in the RHOAI dashboard — the running pod does not pick up a new image until restart.

## Optional first build

`tekton.runInitialPipeline` defaults to `false`. To trigger an initial PipelineRun:

```bash
helm upgrade custom-workbench charts/custom-workbench/ \
  --set tekton.runInitialPipeline=true
```

Ensure an image matching the current `global.imageTag` in `values.yaml` exists in Quay before the first GitOps sync (run one pipeline build or push manually).

## Local validation

```bash
helm template custom-workbench charts/custom-workbench/ --debug
helm template custom-workbench charts/custom-workbench/ \
  -f charts/custom-workbench/values-lab.yaml \
  --set secrets.create=true
```
