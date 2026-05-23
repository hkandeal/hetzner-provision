#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${DEPLOY_DIR}/.." && pwd)"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

load_env() {
  local env_file="${DEPLOY_DIR}/.env"
  if [[ -f "${env_file}" ]]; then
    set -a && source "${env_file}" && set +a
  elif [[ -f "${REPO_ROOT}/.env" ]]; then
    set -a && source "${REPO_ROOT}/.env" && set +a
  else
    die "Missing deploy/.env — copy deploy/env.example to deploy/.env"
  fi
  OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/output}"
  MGMT_CLUSTER_NAME="${MGMT_CLUSTER_NAME:-hetzner-mgmt}"
  CAPI_INFRA_VERSION="${CAPI_INFRA_VERSION:-hetzner:v1.1.4}"
  CAPI_FLAVOR="${CAPI_FLAVOR:-hetzner-hcloud-control-planes}"
  mkdir -p "${OUTPUT_DIR}"
}

require_cmd() {
  for c in "$@"; do
    command -v "${c}" >/dev/null 2>&1 || die "Required command not found: ${c}"
  done
}

ensure_k8s_version() {
  [[ "${KUBERNETES_VERSION}" == v* ]] || KUBERNETES_VERSION="v${KUBERNETES_VERSION}"
  export KUBERNETES_VERSION
}

use_mgmt_cluster() {
  export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
  kubectl config use-context "kind-${MGMT_CLUSTER_NAME}" >/dev/null
}

use_workload_kubeconfig() {
  local kc="${OUTPUT_DIR}/${CLUSTER_NAME}-kubeconfig.yaml"
  [[ -f "${kc}" ]] || die "Workload kubeconfig missing: ${kc}"
  export KUBECONFIG="${kc}"
}

export_clusterctl_env() {
  export HCLOUD_CONTROL_PLANE_MACHINE_TYPE HCLOUD_WORKER_MACHINE_TYPE HCLOUD_REGION
  export KUBERNETES_VERSION SSH_KEY_NAME CLUSTER_NAME
  export CONTROL_PLANE_MACHINE_COUNT WORKER_MACHINE_COUNT
}
