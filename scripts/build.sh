#!/usr/bin/env bash
set -euo pipefail

MANIFESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="${SOURCE_ROOT:-${MANIFESTS_ROOT}/../my-custom-workbench}"
# shellcheck source=env.defaults.sh
source "${MANIFESTS_ROOT}/scripts/env.defaults.sh"

BUILD_RUNTIME=false
for arg in "$@"; do
  case "${arg}" in
    --runtime) BUILD_RUNTIME=true ;;
    -h|--help)
      echo "Usage: $0 [--runtime]"
      echo "  Builds workbench image (default) or runtime image (--runtime)."
      echo "  Builds from SOURCE_ROOT (${SOURCE_ROOT}). Override with SOURCE_ROOT=..."
      echo "  Set QUAY_IMAGE / QUAY_RUNTIME_IMAGE / BASE_IMAGE via env or env.defaults.sh"
      exit 0
      ;;
  esac
done

if [[ ! -f "${SOURCE_ROOT}/Containerfile" ]]; then
  echo "Source repo not found at ${SOURCE_ROOT} (expected Containerfile)." >&2
  exit 1
fi

cd "${SOURCE_ROOT}"

if [[ "${BUILD_RUNTIME}" == true ]]; then
  echo "Building runtime image from Containerfile.runtime (base: ${RUNTIME_BASE_IMAGE})"
  podman build \
    --platform linux/amd64 \
    --build-arg "RUNTIME_BASE_IMAGE=${RUNTIME_BASE_IMAGE}" \
    -f Containerfile.runtime \
    -t "${QUAY_RUNTIME_IMAGE}" \
    .
  echo "Built: ${QUAY_RUNTIME_IMAGE}"
else
  echo "Building workbench image from Containerfile (base: ${BASE_IMAGE})"
  podman build \
    --platform linux/amd64 \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    -f Containerfile \
    -t "${QUAY_IMAGE}" \
    .
  echo "Built: ${QUAY_IMAGE}"
fi
