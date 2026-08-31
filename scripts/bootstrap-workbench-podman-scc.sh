#!/usr/bin/env bash
# Create custom-workbench-podman SCC and grant it to the workbench ServiceAccount.
# Requires cluster-admin (oc adm policy / SCC create).
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKBENCH_NS="${WORKBENCH_NS:-custom-workbench-demo}"
WORKBENCH_SA="${WORKBENCH_SA:-custom-workbench-demo}"
SCC_NAME="${SCC_NAME:-custom-workbench-podman}"

oc apply -f "${MANIFESTS_ROOT}/gitops/custom-workbench-podman-scc.yaml"

# Custom SCCs do not get system:openshift:scc:<name> ClusterRoles; bind via users: field.
oc adm policy add-scc-to-user "${SCC_NAME}" -z "${WORKBENCH_SA}" -n "${WORKBENCH_NS}"

# If Argo previously managed this SCC from Helm, stop pruning it when removed from the chart.
oc annotate scc "${SCC_NAME}" \
  argocd.argoproj.io/sync-options=Prune=false \
  --overwrite 2>/dev/null || true

echo "SCC ${SCC_NAME} ready for ${WORKBENCH_NS}/${WORKBENCH_SA}"
oc get scc "${SCC_NAME}" -o jsonpath='users={.users}{"\n"}'
