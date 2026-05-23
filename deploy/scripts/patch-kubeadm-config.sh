#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
ensure_k8s_version
use_mgmt_cluster

KCP_NAME="${CLUSTER_NAME}-control-plane"
TEMPLATE="${DEPLOY_DIR}/templates/kubeadm-clusterconfiguration.yaml"
[[ -f "${TEMPLATE}" ]] || die "Missing template: ${TEMPLATE}"

CP_HOST="$(kubectl get cluster "${CLUSTER_NAME}" -o jsonpath='{.spec.controlPlaneEndpoint.host}' 2>/dev/null || true)"
CP_PORT="$(kubectl get cluster "${CLUSTER_NAME}" -o jsonpath='{.spec.controlPlaneEndpoint.port}' 2>/dev/null || echo 6443)"

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
sed -e "s/^clusterName:.*/clusterName: ${CLUSTER_NAME}/" \
    -e "s/^kubernetesVersion:.*/kubernetesVersion: ${KUBERNETES_VERSION}/" \
    -e "s|^controlPlaneEndpoint:.*|controlPlaneEndpoint: ${CP_HOST:-0.0.0.0}:${CP_PORT}|" \
    "${TEMPLATE}" > "${TMP}"

log "Patching KubeadmControlPlane ${KCP_NAME}..."
kubectl get kubeadmcontrolplane "${KCP_NAME}" -o json | ruby -ryaml -rjson - "${TMP}" <<'RUBY' | kubectl apply -f -
kcp = JSON.parse(STDIN.read)
cfg = YAML.load_file(ARGV[0])
kcp["spec"] ||= {}
kcp["spec"]["kubeadmConfigSpec"] ||= {}
kcp["spec"]["kubeadmConfigSpec"]["clusterConfiguration"] = cfg
puts JSON.pretty_generate(kcp)
RUBY

log "KubeadmControlPlane patched (InternalIP first for kubelet-preferred-address-types)"
