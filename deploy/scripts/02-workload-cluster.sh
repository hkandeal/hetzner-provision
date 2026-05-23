#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
ensure_k8s_version
export_clusterctl_env
require_cmd kubectl clusterctl
use_mgmt_cluster

GEN_DIR="${DEPLOY_DIR}/generated"
mkdir -p "${GEN_DIR}"
MANIFEST="${GEN_DIR}/${CLUSTER_NAME}.yaml"

if kubectl get cluster "${CLUSTER_NAME}" >/dev/null 2>&1; then
  log "Cluster ${CLUSTER_NAME} already exists on management cluster"
else
  log "Generating workload cluster manifest..."
  clusterctl generate cluster "${CLUSTER_NAME}" \
    --infrastructure "${CAPI_INFRA_VERSION}" \
    --flavor "${CAPI_FLAVOR}" \
    --kubernetes-version "${KUBERNETES_VERSION}" \
    --control-plane-machine-count "${CONTROL_PLANE_MACHINE_COUNT}" \
    --worker-machine-count "${WORKER_MACHINE_COUNT}" \
    > "${MANIFEST}"

  log "Applying ${MANIFEST}"
  kubectl apply -f "${MANIFEST}"
fi

log "Waiting for Cluster ${CLUSTER_NAME} to be provisioned (up to 45m)..."
kubectl wait --for=condition=Ready "cluster/${CLUSTER_NAME}" --timeout=45m

log "Waiting for control plane to be initialized..."
kubectl wait --for=condition=ControlPlaneInitialized "cluster/${CLUSTER_NAME}" --timeout=45m

"${SCRIPT_DIR}/patch-kubeadm-config.sh"

log "Exporting workload kubeconfig..."
clusterctl get kubeconfig "${CLUSTER_NAME}" > "${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml"
chmod 600 "${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml"

use_workload_kubeconfig
kubectl get nodes -o wide
log "Workload cluster ready. Kubeconfig: ${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml"
