#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
use_mgmt_cluster
require_cmd kubectl

SNAP="${OUTPUT_DIR}/snapshot-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${SNAP}"

log "Exporting CAPI objects to ${SNAP}..."
for kind in cluster kubeadmcontrolplane machinedeployment hetznercluster hcloudmachinetemplate; do
  kubectl get "${kind}" -A -o yaml > "${SNAP}/${kind}.yaml" 2>/dev/null || true
done

if [[ -f "${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml" ]]; then
  cp "${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml" "${SNAP}/"
fi

log "Snapshot written to ${SNAP}"
