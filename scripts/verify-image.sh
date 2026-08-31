#!/usr/bin/env bash
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.defaults.sh
source "${MANIFESTS_ROOT}/scripts/env.defaults.sh"

VERIFY_RUNTIME=false
for arg in "$@"; do
  case "${arg}" in
    --runtime) VERIFY_RUNTIME=true ;;
    -h|--help)
      echo "Usage: $0 [--runtime]"
      exit 0
      ;;
  esac
done

IMAGE="${QUAY_IMAGE}"
if [[ "${VERIFY_RUNTIME}" == true ]]; then
  IMAGE="${QUAY_RUNTIME_IMAGE}"
fi

echo "Verifying opencode in ${IMAGE}"
podman run --rm --pull=never --platform linux/amd64 \
  --user 1001 \
  -e HOME=/opt/app-root/src \
  --entrypoint /bin/bash \
  "${IMAGE}" -lc 'opencode --version'
echo "OK"
