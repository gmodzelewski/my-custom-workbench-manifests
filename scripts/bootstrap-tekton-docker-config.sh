#!/usr/bin/env bash
# Merge Quay push + OpenShift internal registry + Red Hat registry auths for Tekton buildah.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.defaults.sh
source "${ROOT}/scripts/env.defaults.sh"

: "${RHOAI_NAMESPACE:=redhat-ods-applications}"
: "${QUAY_SECRET:=quay-push-credentials}"
: "${INTERNAL_REGISTRY_SECRET:=internal-registry-pull}"
: "${REDHAT_REGISTRY_SECRET:=redhat-registry-pull}"
: "${TEKTON_DOCKER_CONFIG_SECRET:=tekton-docker-config}"

require_secret() {
  local name="$1"
  if ! oc get secret "${name}" -n "${RHOAI_NAMESPACE}" &>/dev/null; then
    echo "error: secret ${name} not found in ${RHOAI_NAMESPACE}" >&2
    exit 1
  fi
}

require_secret "${QUAY_SECRET}"
require_secret "${INTERNAL_REGISTRY_SECRET}"
require_secret "${REDHAT_REGISTRY_SECRET}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

decode_dockerconfig() {
  oc get secret "$1" -n "${RHOAI_NAMESPACE}" \
    -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d >"${TMPDIR}/$1.json"
}

decode_dockerconfig "${QUAY_SECRET}"
decode_dockerconfig "${INTERNAL_REGISTRY_SECRET}"
decode_dockerconfig "${REDHAT_REGISTRY_SECRET}"

jq -s '
  .[0] as $internal | .[1] as $redhat | .[2] as $quay |
  {auths: ($internal.auths * $redhat.auths * $quay.auths)}
' \
  "${TMPDIR}/${INTERNAL_REGISTRY_SECRET}.json" \
  "${TMPDIR}/${REDHAT_REGISTRY_SECRET}.json" \
  "${TMPDIR}/${QUAY_SECRET}.json" >"${TMPDIR}/merged.json"

oc create secret generic "${TEKTON_DOCKER_CONFIG_SECRET}" \
  --from-file=.dockerconfigjson="${TMPDIR}/merged.json" \
  -n "${RHOAI_NAMESPACE}" \
  --dry-run=client -o yaml | oc apply -f -

echo "Applied ${TEKTON_DOCKER_CONFIG_SECRET} in ${RHOAI_NAMESPACE}"
echo "Registries:"
jq -r '.auths | keys[]' "${TMPDIR}/merged.json"
