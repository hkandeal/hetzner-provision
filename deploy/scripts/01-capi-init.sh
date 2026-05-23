#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
require_cmd kubectl clusterctl
use_mgmt_cluster

log "Initializing Cluster API with Hetzner provider (${CAPI_INFRA_VERSION})..."
clusterctl init \
  --core cluster-api \
  --bootstrap kubeadm \
  --control-plane kubeadm \
  --infrastructure "${CAPI_INFRA_VERSION}"

for s in hetzner robot-ssh; do
  if kubectl get secret "${s}" -n default >/dev/null 2>&1; then
    log "Secret ${s} already exists — skipping"
    continue
  fi
done

if ! kubectl get secret hetzner -n default >/dev/null 2>&1; then
  kubectl create secret generic hetzner \
    --from-literal=hcloud="${HCLOUD_TOKEN}" \
    --from-literal=robot-user="${HETZNER_ROBOT_USER:-}" \
    --from-literal=robot-password="${HETZNER_ROBOT_PASSWORD:-}"
  kubectl label secret hetzner clusterctl.cluster.x-k8s.io/move="" --overwrite
fi

if ! kubectl get secret robot-ssh -n default >/dev/null 2>&1; then
  kubectl create secret generic robot-ssh \
    --from-literal=sshkey-name="${SSH_KEY_NAME}" \
    --from-file=ssh-privatekey="${HETZNER_SSH_PRIV_PATH}" \
    --from-file=ssh-publickey="${HETZNER_SSH_PUB_PATH}"
  kubectl label secret robot-ssh clusterctl.cluster.x-k8s.io/move="" --overwrite
fi

kubectl wait --for=condition=Available deployment -n capi-system -l cluster.x-k8s.io/provider=control-plane --timeout=300s || true
log "CAPI initialized on management cluster"
