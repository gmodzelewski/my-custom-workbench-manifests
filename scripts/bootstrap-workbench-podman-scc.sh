#!/usr/bin/env bash
# Grant the workbench ServiceAccount an SCC for in-workbench Podman.
# Prefers built-in nested-container (OCP 4.20+); falls back to custom-workbench-podman.
# Requires cluster-admin (oc adm policy / SCC create).
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKBENCH_NS="${WORKBENCH_NS:-custom-workbench-demo}"
WORKBENCH_SA="${WORKBENCH_SA:-custom-workbench-demo}"
SCC_NAME="${SCC_NAME:-nested-container}"
FALLBACK_SCC="${FALLBACK_SCC:-custom-workbench-podman}"

if ! oc get scc "${SCC_NAME}" &>/dev/null; then
  echo "SCC ${SCC_NAME} not found (requires OCP 4.20+)."
  echo "Applying fallback ${FALLBACK_SCC}..."
  SCC_NAME="${FALLBACK_SCC}"
  oc apply -f "${MANIFESTS_ROOT}/gitops/custom-workbench-podman-scc.yaml"
  oc annotate scc "${SCC_NAME}" \
    argocd.argoproj.io/sync-options=Prune=false \
    --overwrite 2>/dev/null || true
fi

oc adm policy add-scc-to-user "${SCC_NAME}" -z "${WORKBENCH_SA}" -n "${WORKBENCH_NS}"

if [[ "${SCC_NAME}" == "nested-container" ]] && oc get scc custom-workbench-podman &>/dev/null; then
  echo "Removing legacy custom-workbench-podman binding (priority 10 preempts nested-container)..."
  oc adm policy remove-scc-from-user custom-workbench-podman -z "${WORKBENCH_SA}" -n "${WORKBENCH_NS}" 2>/dev/null || true
fi

if oc get statefulset "${WORKBENCH_SA}" -n "${WORKBENCH_NS}" &>/dev/null; then
  WORKBENCH_NS="${WORKBENCH_NS}" WORKBENCH_NAME="${WORKBENCH_SA}" SCC_NAME="${SCC_NAME}" \
    "${MANIFESTS_ROOT}/scripts/patch-workbench-statefulset-scc.sh"
fi

echo "SCC ${SCC_NAME} granted to ${WORKBENCH_NS}/${WORKBENCH_SA}"
echo "GitOps PostSync job also patches the StatefulSet when workbench.podman.enabled=true."
oc get scc "${SCC_NAME}" -o jsonpath='users={.users}{"\n"}'
