#!/usr/bin/env bash
# Create workbench-git-credentials in the workbench namespace from github-pat
# in redhat-ods-applications. Safe to re-run (oc apply semantics via delete/create).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.defaults.sh
source "${ROOT}/scripts/env.defaults.sh"

: "${RHOAI_NAMESPACE:=redhat-ods-applications}"
: "${GITHUB_PAT_SECRET:=github-pat}"
: "${WORKBENCH_NAMESPACE:=${DEMO_NAMESPACE}}"
: "${WORKBENCH_GIT_SECRET:=workbench-git-credentials}"
: "${GIT_HOST:=github.com}"
: "${GIT_USERNAME:=gmodzelewski}"

if ! oc get secret "${GITHUB_PAT_SECRET}" -n "${RHOAI_NAMESPACE}" &>/dev/null; then
  echo "error: secret ${GITHUB_PAT_SECRET} not found in ${RHOAI_NAMESPACE}" >&2
  echo "Create it first — see gitops/README.md" >&2
  exit 1
fi

PAT="$(oc get secret "${GITHUB_PAT_SECRET}" -n "${RHOAI_NAMESPACE}" \
  -o jsonpath='{.data.password}' | base64 -d)"

GITCONFIG="$(mktemp)"
trap 'rm -f "${GITCONFIG}"' EXIT
cat >"${GITCONFIG}" <<EOF
[credential]
    helper = store --file /opt/app-root/src/.git-credentials
[user]
    name = ${GIT_USERNAME}
    email = ${GIT_USERNAME}@users.noreply.github.com
EOF

oc create secret generic "${WORKBENCH_GIT_SECRET}" \
  --from-literal=.git-credentials="https://${GIT_USERNAME}:${PAT}@${GIT_HOST}" \
  --from-file=.gitconfig="${GITCONFIG}" \
  -n "${WORKBENCH_NAMESPACE}" \
  --dry-run=client -o yaml | oc apply -f -

echo "Applied secret ${WORKBENCH_GIT_SECRET} in ${WORKBENCH_NAMESPACE}"
echo "Restart the workbench pod if it was already running:"
echo "  oc delete pod -l notebook-name=${WORKBENCH_NAMESPACE} -n ${WORKBENCH_NAMESPACE}"
