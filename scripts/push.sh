#!/usr/bin/env bash
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.defaults.sh
source "${MANIFESTS_ROOT}/scripts/env.defaults.sh"

PUSH_RUNTIME=false
for arg in "$@"; do
  case "${arg}" in
    --runtime) PUSH_RUNTIME=true ;;
    -h|--help)
      echo "Usage: $0 [--runtime]"
      echo "  Pushes the locally built image to Quay (requires podman login quay.io)."
      exit 0
      ;;
  esac
done

if [[ "${PUSH_RUNTIME}" == true ]]; then
  echo "Pushing ${QUAY_RUNTIME_IMAGE}"
  podman push "${QUAY_RUNTIME_IMAGE}"
else
  echo "Pushing ${QUAY_IMAGE}"
  podman push "${QUAY_IMAGE}"
fi

echo "Push complete."
