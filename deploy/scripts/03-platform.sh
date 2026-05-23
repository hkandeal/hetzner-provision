#!/usr/bin/env bash
# Install platform add-ons per deploy/profiles/full-platform.yaml
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
use_workload_kubeconfig
require_cmd kubectl helm

COMP="${REPO_ROOT}/components"

log "Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

log "Installing Hetzner CCM..."
kubectl create secret generic hcloud \
  --from-literal=token="${HCLOUD_TOKEN}" \
  -n kube-system --dry-run=client -o yaml | kubectl apply -f -
helm repo add syself https://charts.syself.com/ 2>/dev/null || true
helm repo update syself
helm upgrade --install ccm syself/ccm-hetzner -n kube-system --create-namespace

log "Installing Hetzner CSI..."
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/main/deploy/kubernetes/hcloud-csi.yml

log "Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

log "Installing kubelet CSR approver..."
kubectl apply -f "${COMP}/csr/rbac-csr-approver.yaml"
kubectl apply -f "${COMP}/csr/csr-approver-deployment.yaml"

log "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update jetstack
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  -f "${COMP}/cert-manager/values.yaml"
kubectl apply -f "${COMP}/cert-manager/cluster_issuer.yaml" || true

log "Installing Kong ingress..."
helm repo add kong https://charts.konghq.com 2>/dev/null || true
helm repo update kong
helm upgrade --install kong kong/kong \
  --namespace kong --create-namespace \
  -f "${COMP}/ingress/kong/values.yaml"

log "Installing Prometheus stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f "${COMP}/observability/prometheus/values.yaml"

log "Installing Loki..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana
helm upgrade --install loki grafana/loki \
  --namespace logging --create-namespace \
  -f "${COMP}/observability/logging/loki/values_loki.yaml"

log "Installing Argo CD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f "${COMP}/argocd/values.yaml"

log "Installing Netdata..."
helm repo add netdata https://netdata.github.io/helmchart 2>/dev/null || true
helm repo update netdata
helm upgrade --install netdata netdata/netdata \
  --namespace netdata --create-namespace \
  -f "${COMP}/observability/netdata/values.yaml"

log "Platform profile 'full-platform' applied. See docs/components.md for tweaks."
