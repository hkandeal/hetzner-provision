#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
use_workload_kubeconfig
require_cmd kubectl

log "Nodes:"
kubectl get nodes -o wide

log "System pods (non-Running):"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | head -30 || true

for ns_deploy in kube-system/coredns kube-system/ccm; do
  ns="${ns_deploy%%/*}"
  dep="${ns_deploy##*/}"
  kubectl rollout status "deployment/${dep}" -n "${ns}" --timeout=120s 2>/dev/null || true
done

if kubectl get ingressclass kong >/dev/null 2>&1; then
  log "Kong ingress class present"
fi

if [[ -f "${REPO_ROOT}/tests/ingress_cert/ping.yaml" ]]; then
  log "Optional smoke test manifest: tests/ingress_cert/ping.yaml (apply after DNS)"
fi

log "Validation complete"
