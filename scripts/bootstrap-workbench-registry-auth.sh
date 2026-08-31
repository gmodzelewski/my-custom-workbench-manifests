#!/usr/bin/env bash
# Merge internal + Red Hat registry pull auths for in-workbench podman build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.defaults.sh
source "${ROOT}/scripts/env.defaults.sh"

: "${RHOAI_NAMESPACE:=redhat-ods-applications}"
: "${WORKBENCH_NAMESPACE:=custom-workbench-demo}"
: "${INTERNAL_REGISTRY_SECRET:=internal-registry-pull}"
: "${REDHAT_REGISTRY_SECRET:=redhat-registry-pull}"
: "${WORKBENCH_REGISTRY_SECRET:=workbench-registry-auth}"

require_secret() {
  local name="$1" ns="$2"
  if ! oc get secret "${name}" -n "${ns}" &>/dev/null; then
    echo "error: secret ${name} not found in ${ns}" >&2
    exit 1
  fi
}

require_secret "${INTERNAL_REGISTRY_SECRET}" "${RHOAI_NAMESPACE}"
require_secret "${REDHAT_REGISTRY_SECRET}" "${RHOAI_NAMESPACE}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

decode_dockerconfig() {
  oc get secret "$1" -n "${RHOAI_NAMESPACE}" \
    -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d >"${TMPDIR}/$1.json"
}

decode_dockerconfig "${INTERNAL_REGISTRY_SECRET}"
decode_dockerconfig "${REDHAT_REGISTRY_SECRET}"

jq -s '{auths: (.[0].auths * .[1].auths)}' \
  "${TMPDIR}/${INTERNAL_REGISTRY_SECRET}.json" \
  "${TMPDIR}/${REDHAT_REGISTRY_SECRET}.json" >"${TMPDIR}/merged.json"

oc create secret generic "${WORKBENCH_REGISTRY_SECRET}" \
  --from-file=.dockerconfigjson="${TMPDIR}/merged.json" \
  -n "${WORKBENCH_NAMESPACE}" \
  --dry-run=client -o yaml | oc apply -f -

echo "Applied ${WORKBENCH_REGISTRY_SECRET} in ${WORKBENCH_NAMESPACE}"
jq -r '.auths | keys[]' "${TMPDIR}/merged.json"
