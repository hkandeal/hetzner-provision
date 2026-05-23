#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
require_cmd kubectl clusterctl kind hcloud helm

log "clusterctl: $(clusterctl version -o short 2>/dev/null || clusterctl version | head -1)"
log "kubectl: $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 || kubectl version --client)"

for var in HCLOUD_TOKEN SSH_KEY_NAME HCLOUD_REGION HCLOUD_CONTROL_PLANE_MACHINE_TYPE HCLOUD_WORKER_MACHINE_TYPE CLUSTER_NAME KUBERNETES_VERSION; do
  [[ -n "${!var:-}" ]] || die "Unset required variable: ${var}"
done

[[ -f "${HETZNER_SSH_PRIV_PATH:-}" ]] || die "SSH private key missing: ${HETZNER_SSH_PRIV_PATH}"
[[ -f "${HETZNER_SSH_PUB_PATH:-}" ]] || die "SSH public key missing: ${HETZNER_SSH_PUB_PATH}"

for bad in cpx21 cpx31; do
  if [[ "${HCLOUD_CONTROL_PLANE_MACHINE_TYPE}" == "${bad}" ]] || [[ "${HCLOUD_WORKER_MACHINE_TYPE}" == "${bad}" ]]; then
    die "Server type ${bad} is not reliable in ${HCLOUD_REGION} for new CAPI rolls — use cpx32/ccx23 (see docs/upgrade/issues-and-lessons.md)"
  fi
done

log "Checking Hetzner API and server types for location=${HCLOUD_REGION}..."
export HCLOUD_TOKEN
hcloud server-type list -o columns=name,cores,memory,price_hourly >/dev/null

for t in "${HCLOUD_CONTROL_PLANE_MACHINE_TYPE}" "${HCLOUD_WORKER_MACHINE_TYPE}"; do
  if ! hcloud server-type describe "${t}" >/dev/null 2>&1; then
    die "Unknown server type: ${t}"
  fi
done

log "Preflight OK (region=${HCLOUD_REGION}, cp=${HCLOUD_CONTROL_PLANE_MACHINE_TYPE}, worker=${HCLOUD_WORKER_MACHINE_TYPE}, k8s=${KUBERNETES_VERSION})"
