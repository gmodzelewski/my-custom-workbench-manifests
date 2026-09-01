#!/usr/bin/env bash
# Remove leftover Podman vfs on the workbench PVC (often root-owned after a
# privileged cleanup mkdir). Notebook UID 1001 cannot mkdir there.
# Scale the Notebook down first so the RWO PVC is free.
set -euo pipefail

: "${WORKBENCH_NS:=custom-workbench-demo}"
: "${WORKBENCH_NAME:=custom-workbench-demo}"
: "${WORKBENCH_UID:=1001}"

CLEANUP_POD="pvc-podman-storage-cleanup"

oc scale "statefulset/${WORKBENCH_NAME}" -n "${WORKBENCH_NS}" --replicas=0
oc delete pod "${WORKBENCH_NAME}-0" -n "${WORKBENCH_NS}" --ignore-not-found --timeout=90s || true
oc wait --for=delete "pod/${WORKBENCH_NAME}-0" -n "${WORKBENCH_NS}" --timeout=90s || true

oc delete pod "${CLEANUP_POD}" -n "${WORKBENCH_NS}" --ignore-not-found --wait=true

oc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${CLEANUP_POD}
  namespace: ${WORKBENCH_NS}
spec:
  restartPolicy: Never
  securityContext:
    runAsUser: 0
    runAsNonRoot: false
  containers:
    - name: cleanup
      image: registry.access.redhat.com/ubi9-minimal:latest
      command:
        - /bin/sh
        - -c
        - |
          set -e
          rm -rf /data/.local/share/containers
          rm -f /data/.local/.git-credentials /data/.local/.gitconfig 2>/dev/null || true
          mkdir -p /data/.local/share/containers/storage /data/.local /data/.config/containers
          chown -R ${WORKBENCH_UID}:${WORKBENCH_UID} /data/.local /data/.config
          chmod -R ug+rwX /data/.local /data/.config
          echo cleaned
          ls -ld /data/.local/share/containers /data/.local/share/containers/storage
          df -h /data
      volumeMounts:
        - name: home
          mountPath: /data
  volumes:
    - name: home
      persistentVolumeClaim:
        claimName: ${WORKBENCH_NAME}
EOF

oc wait --for=jsonpath='{.status.phase}'=Succeeded "pod/${CLEANUP_POD}" -n "${WORKBENCH_NS}" --timeout=120s
oc logs -n "${WORKBENCH_NS}" "${CLEANUP_POD}"
oc delete pod "${CLEANUP_POD}" -n "${WORKBENCH_NS}" --wait=true

oc scale "statefulset/${WORKBENCH_NAME}" -n "${WORKBENCH_NS}" --replicas=1
oc wait --for=condition=Ready "pod/${WORKBENCH_NAME}-0" -n "${WORKBENCH_NS}" --timeout=180s
echo "Workbench ${WORKBENCH_NS}/${WORKBENCH_NAME} is Ready; podman storage owned by ${WORKBENCH_UID}."
