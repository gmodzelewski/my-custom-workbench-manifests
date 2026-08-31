#!/usr/bin/env bash
# Sync GitHub webhook URL + secret for the source repo EventListener route.
# Requires: oc, gh (authenticated), github-webhook-secret in redhat-ods-applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.defaults.sh
source "${ROOT}/scripts/env.defaults.sh"

: "${RHOAI_NAMESPACE:=redhat-ods-applications}"
: "${WEBHOOK_SECRET_NAME:=github-webhook-secret}"
: "${EVENTLISTENER_ROUTE:=el-custom-workbench-opencode}"
: "${SOURCE_REPO:=gmodzelewski/my-custom-workbench}"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI required" >&2
  exit 1
fi

WEBHOOK_URL="$(oc get route "${EVENTLISTENER_ROUTE}" -n "${RHOAI_NAMESPACE}" \
  -o jsonpath='https://{.spec.host}{"\n"}')"
WEBHOOK_SECRET="$(oc get secret "${WEBHOOK_SECRET_NAME}" -n "${RHOAI_NAMESPACE}" \
  -o jsonpath='{.data.WebHookSecretKey}' | base64 -d)"

HOOK_ID="$(gh api "repos/${SOURCE_REPO}/hooks" --jq \
  "[.[] | select(.config.url == \"${WEBHOOK_URL}\")][0].id")"

if [[ -z "${HOOK_ID}" || "${HOOK_ID}" == "null" ]]; then
  echo "Creating webhook on ${SOURCE_REPO} -> ${WEBHOOK_URL}"
  gh api -X POST "repos/${SOURCE_REPO}/hooks" \
    -f "name=web" \
    -f "active=true" \
    -f "events[]=push" \
    -f "config[url]=${WEBHOOK_URL}" \
    -f "config[content_type]=json" \
    -f "config[secret]=${WEBHOOK_SECRET}" \
    -f "config[insecure_ssl]=0" >/dev/null
else
  echo "Updating webhook ${HOOK_ID} on ${SOURCE_REPO}"
  gh api -X PATCH "repos/${SOURCE_REPO}/hooks/${HOOK_ID}" \
    -f "active=true" \
    -f "events[]=push" \
    -f "config[url]=${WEBHOOK_URL}" \
    -f "config[content_type]=json" \
    -f "config[secret]=${WEBHOOK_SECRET}" \
    -f "config[insecure_ssl]=0" >/dev/null
fi

HAS_SECRET="$(gh api "repos/${SOURCE_REPO}/hooks" --jq \
  "[.[] | select(.config.url == \"${WEBHOOK_URL}\")][0].config.secret != null")"
if [[ "${HAS_SECRET}" != "true" ]]; then
  echo "error: GitHub webhook secret still not set — check gh auth and hook id" >&2
  exit 1
fi

echo "Webhook configured: ${WEBHOOK_URL} (secret set)"
