#!/usr/bin/env bash
# Patch openshift.io/required-scc onto the workbench StatefulSet pod template.
# RHOAI strips spec.template.metadata on the Notebook CR and does not propagate
# openshift.io/required-scc from Notebook metadata to pods.
set -euo pipefail

WORKBENCH_NS="${WORKBENCH_NS:-custom-workbench-demo}"
WORKBENCH_NAME="${WORKBENCH_NAME:-custom-workbench-demo}"
SCC_NAME="${SCC_NAME:-nested-container}"

if ! oc get statefulset "${WORKBENCH_NAME}" -n "${WORKBENCH_NS}" &>/dev/null; then
  echo "ERROR: statefulset/${WORKBENCH_NAME} not found in ${WORKBENCH_NS}" >&2
  echo "Start the workbench once so the notebook controller creates the StatefulSet." >&2
  exit 1
fi

oc patch statefulset "${WORKBENCH_NAME}" -n "${WORKBENCH_NS}" --type merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"openshift.io/required-scc\":\"${SCC_NAME}\"}}}}}"

echo "Patched statefulset/${WORKBENCH_NAME} openshift.io/required-scc=${SCC_NAME}"
echo "Restart the workbench pod if it is already running:"
echo "  oc delete pod ${WORKBENCH_NAME}-0 -n ${WORKBENCH_NS}"
