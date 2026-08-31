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

## Secrets (lab vs production)

By default `secrets.create: false` in `charts/custom-workbench/values.yaml`. Create secrets manually before the Tekton pipeline can run:

| Secret | Type | Keys | Used by |
|--------|------|------|---------|
| `quay-push-credentials` | `kubernetes.io/dockerconfigjson` | `.dockerconfigjson` | Tekton buildah push |
| `github-pat` | `kubernetes.io/basic-auth` | `username`, `password` | Tekton git push to manifests repo |
| `workbench-git-credentials` | `Opaque` | `.git-credentials`, `.gitconfig` | Workbench git push/clone (workbench namespace) |
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
```

After bootstrap, restart the workbench if it was already running so the pod mounts the secret.

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
