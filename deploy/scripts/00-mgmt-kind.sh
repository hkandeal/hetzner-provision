#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
require_cmd kind kubectl

if kind get clusters 2>/dev/null | grep -qx "${MGMT_CLUSTER_NAME}"; then
  log "Kind cluster '${MGMT_CLUSTER_NAME}' already exists — skipping create"
else
  log "Creating Kind management cluster: ${MGMT_CLUSTER_NAME}"
  kind create cluster --name "${MGMT_CLUSTER_NAME}"
fi

use_mgmt_cluster
kubectl cluster-info
log "Management cluster ready (context: kind-${MGMT_CLUSTER_NAME})"
