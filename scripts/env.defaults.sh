# Source from manifests repo root: source scripts/env.defaults.sh
# Override any value in the environment before running build/push scripts.

: "${QUAY_ORG:=modzelewski}"
: "${QUAY_REPO:=custom-workbench-opencode}"
: "${IMAGE_TAG:=1.0}"
: "${QUAY_IMAGE:=quay.io/${QUAY_ORG}/${QUAY_REPO}:${IMAGE_TAG}}"
: "${QUAY_RUNTIME_IMAGE:=quay.io/${QUAY_ORG}/${QUAY_REPO}-runtime:${IMAGE_TAG}}"

# Off-cluster laptop build (podman). On-cluster Tekton pipeline overrides base image params.
: "${BASE_IMAGE:=registry.redhat.io/rhoai/odh-workbench-jupyter-datascience-cpu-py312-rhel9@sha256:0805b2819850f4705a8cde156b7face098400b2d1196182587c2650433fa8625}"
: "${RUNTIME_BASE_IMAGE:=registry.redhat.io/rhoai/odh-pipeline-runtime-datascience-cpu-py312-rhel9@sha256:175cae5e7070f704b8649a9060e9739b0d99b0d029e1f8253c6585da80e7eb93}"

: "${DEMO_NAMESPACE:=custom-workbench-demo}"
: "${SOURCE_GIT_URL:=https://github.com/gmodzelewski/my-custom-workbench.git}"
: "${MANIFESTS_GIT_URL:=https://github.com/gmodzelewski/my-custom-workbench-manifests.git}"
