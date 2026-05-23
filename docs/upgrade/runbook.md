# Upgrade runbook (future minor hops)

Use this for the next **single minor** bump (e.g. v1.36.1 → v1.37.x). Full history: [execution.md](execution.md).

## Prerequisites

```bash
export KUBECONFIG="$PWD/Clustzilla-kubeconfig.yaml"
export SSH_KEY="${HETZNER_SSH_PRIV_PATH:-$HOME/.ssh/id_ed25519}"
export CP_HOST="5.223.76.164"
```

- Management cluster running: `kind get clusters` → `clustzilla-control`
- Local tools: `kubectl` and `clusterctl` within **±1 minor** of target
- Maintenance window: **30–90 minutes**

## Before each hop

### 1. etcd snapshot (control plane)

```bash
ssh -i "$SSH_KEY" root@$CP_HOST '
ETCDCTL_API=3 etcdctl snapshot save /root/etcd-backup-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
ls -la /root/etcd-backup-*.db | tail -1
'
```

Copy the snapshot off the node.

### 2. Helm backup

```bash
mkdir -p backups/$(date +%Y%m%d)
for rel in kong kong argocd argocd cert-manager cert-manager monitoring prometheus-stack logging loki logging promtail kube-system ccm-hetzner netdata netdata; do
  ns="${rel%% *}"; name="${rel##* }"
  helm get values -a "$name" -n "$ns" > "backups/$(date +%Y%m%d)/helm-${ns}-${name}.yaml" 2>/dev/null || true
done
```

### 3. Fix `kubeadm-config` version

Ensure `kubernetesVersion` in ConfigMap matches **current** server version:

```bash
kubectl get cm kubeadm-config -n kube-system -o jsonpath='{.data.ClusterConfiguration}' | grep kubernetesVersion
```

If wrong, apply reference config:

```bash
kubectl create configmap kubeadm-config -n kube-system \
  --from-file=ClusterConfiguration=kubernetes/clustzilla/kubeadm-clusterconfiguration-v1.36.1.yaml \
  --dry-run=client -o yaml | kubectl replace -f -
# Edit kubernetesVersion in that file first for your target hop.
```

Remove `cloud-provider: external` from `apiServer` and `controllerManager` `extraArgs` for clusters on **1.33+**.

## Run one hop

```bash
./scripts/kubeadm-hop.sh v1.37.0   # example next minor
```

The script:

1. Patches `kubeadm-config` to current version
2. Upgrades CP packages and runs `kubeadm upgrade apply`
3. Syncs static pods if apply fails (hash timeout)
4. Strips deprecated manifest/flags
5. Upgrades each worker (cordon → drain → `kubeadm upgrade node` → uncordon)

## Manual recovery (API down / apply failed)

On **control plane** SSH:

```bash
# Deprecated flags (1.33+ / 1.35+)
sed -i 's|--pod-infra-container-image=[^ ]* ||g; s|--cloud-provider=external ||g' /var/lib/kubelet/kubeadm-flags.env
sed -i '/--cloud-provider=external/d' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/--cloud-provider=external/d' /etc/kubernetes/manifests/kube-controller-manager.yaml

# Sync static pod versions to TARGET (e.g. v1.37.0)
TARGET=v1.37.0
UPG=$(ls -td /etc/kubernetes/tmp/kubeadm-upgraded-manifests* 2>/dev/null | head -1)
[ -d "$UPG" ] && cp -a $UPG/*.yaml /etc/kubernetes/manifests/ 2>/dev/null || true
sed -i "s|kube-apiserver:v[0-9.]*|kube-apiserver:${TARGET}|g" /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i "s|kube-controller-manager:v[0-9.]*|kube-controller-manager:${TARGET}|g" /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -i "s|kube-scheduler:v[0-9.]*|kube-scheduler:${TARGET}|g" /etc/kubernetes/manifests/kube-scheduler.yaml

systemctl restart kubelet
```

Wait 2–3 minutes, then from laptop:

```bash
kubectl version
kubectl get nodes
```

## Post-hop validation

```bash
kubectl version
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
kubectl get --raw /readyz

kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-flannel
kubectl get pods -n kube-system -l app.kubernetes.io/name=ccm-hetzner
kubectl get pods -n kube-system | grep csi
kubectl get pods -n kong,argocd,cert-manager,monitoring,logging

# Anything not Running?
kubectl get pods -A --field-selector=status.phase!=Running | grep -v Completed
```

**Stop** if API, etcd, or CNI is unhealthy.

## Worker drain tips

- Use `--disable-eviction` if CCM PDB blocks drain (script does this).
- Stateful workloads (Prometheus, Loki, MySQL) will reschedule; expect brief disruption.
- **Loki:** if `loki-0` is `Pending` with multi-attach, delete the pod and check `kubectl get volumeattachment`.

## CAPI (when machine roll works again)

After fixing `HCloudMachineTemplate` types for `sin`:

```bash
export KUBECONFIG=/tmp/clustzilla-control-kubeconfig.yaml
kubectl patch kubeadmcontrolplane clustzilla-control-plane --type merge \
  -p '{"spec":{"version":"v1.37.0"}}'
kubectl patch machinedeployment clustzilla-md-0 --type merge \
  -p '{"spec":{"template":{"spec":{"version":"v1.37.0"}}}}'
```

Unpause MD only when new server creates succeed in Hetzner console/API.

## Node map

| Role | Node name | IP |
|------|-----------|-----|
| Control plane | `clustzilla-control-plane-b4wbc` | `5.223.76.164` |
| Worker 1 | `clustzilla-md-0-6h7mn-6w226` | `5.223.77.113` |
| Worker 2 | `clustzilla-md-0-6h7mn-9dr5z` | `5.223.56.114` |
