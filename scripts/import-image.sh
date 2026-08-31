#!/usr/bin/env bash
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.defaults.sh
source "${MANIFESTS_ROOT}/scripts/env.defaults.sh"

OCP_NAMESPACE="${OCP_NAMESPACE:-redhat-ods-applications}"
IS_NAME="${IS_NAME:-custom-workbench-opencode}"
IS_TAG="${IS_TAG:-${IMAGE_TAG}}"

echo "Importing ${QUAY_IMAGE} into ImageStream ${IS_NAME}:${IS_TAG} (${OCP_NAMESPACE})"
echo "Note: Tekton pipeline auto-imports after Quay push; use this script for laptop builds only."
oc import-image "${IS_NAME}:${IS_TAG}" \
  --from="${QUAY_IMAGE}" \
  --confirm \
  -n "${OCP_NAMESPACE}"

echo "Done. Confirm in RHOAI dashboard: Settings → Notebook images."
