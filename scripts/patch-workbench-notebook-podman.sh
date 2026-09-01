#!/usr/bin/env bash
# Argo ignoreDifferences skips Notebook .spec.template.spec.containers, so Helm
# securityContext never reaches a live Notebook. Patch it onto the CR.
set -euo pipefail

: "${WORKBENCH_NS:=custom-workbench-demo}"
: "${WORKBENCH_NAME:=custom-workbench-demo}"

oc patch notebook.kubeflow.org "${WORKBENCH_NAME}" -n "${WORKBENCH_NS}" --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/securityContext","value":{"allowPrivilegeEscalation":true,"capabilities":{"add":["SETUID","SETGID"]}}}]'

echo "Patched ${WORKBENCH_NS}/${WORKBENCH_NAME} securityContext (SETUID/SETGID, allowPrivilegeEscalation=true)."
echo "Restart the workbench pod to pick it up:"
echo "  oc delete pod -l notebook-name=${WORKBENCH_NAME} -n ${WORKBENCH_NS}"
