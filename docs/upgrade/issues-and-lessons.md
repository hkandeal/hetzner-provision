# Issues and lessons learned

Problems encountered during **v1.31.6 → v1.36.1** and how they were resolved.

## CAPI / CAPH

### CAPH broken after CAPI upgrade to v1beta1

- **Symptom:** CAPH controller errors: no matches for kind `Cluster` in version `v1beta2`.
- **Cause:** `clusterctl upgrade apply --contract v1beta1` left CRD/API mismatch.
- **Fix:** `clusterctl upgrade apply --contract v1beta2` → CAPI **1.13.2**, CAPH **1.1.4** healthy.

### Rolling upgrade blocked in Singapore

- **Symptom:** New Machine `clustzilla-control-plane-*` fails: `unsupported location for server type` (`cpx31` / `cpx21` in `sin`).
- **Cause:** Hetzner location + server type combination not available for **new** server creates.
- **Fix:** In-place kubeadm on existing nodes; do not rely on CAPI roll until templates use valid types (e.g. `cpx32`, `ccx23` per `hcloud server-type list` with location `sin`).

### Lost third worker

- **Symptom:** During force-drain, node vanished; Hetzner server deleted.
- **Cause:** Aggressive drain + CAPI reconciliation / server removal.
- **Lesson:** Avoid `--force` drain on last worker; use `--disable-eviction` for CCM PDB; pause `MachineDeployment` before destructive ops.
- **Current state:** 2 workers; restore via fixed templates + unpause `clustzilla-md-0`.

## Control plane (single CP)

### kubeadm apply — apiserver hash timeout

- **Symptom:** `kubeadm upgrade apply` upgrades etcd, moves apiserver manifest, then fails: `failed to obtain static Pod hash for component kube-apiserver ... EOF`.
- **Cause:** API unavailable while apiserver restarts; single CP cannot pass hash check in time.
- **Fix:** Copy manifests from `/etc/kubernetes/tmp/kubeadm-upgraded-manifests*` or `sed` image tags; `systemctl restart kubelet`; do **not** rely on second `kubeadm apply` until API is up.

### Apiserver crash: `--cloud-provider=external`

- **Symptom:** `Error: unknown flag: --cloud-provider` (1.33+ apiserver).
- **Cause:** Legacy `KubeadmControlPlane` / `kubeadm-config` still inject flag; kubeadm re-adds it on apply.
- **Fix:** `sed -i '/--cloud-provider=external/d'` on apiserver and controller-manager manifests after each apply.

### Kubelet crash: `--pod-infra-container-image`

- **Symptom:** `failed to parse kubelet flag: unknown flag: --pod-infra-container-image` (1.35+ kubelet).
- **Cause:** Old `kubeadm-flags.env` from pre-1.35 joins.
- **Fix:** Remove flag from `/var/lib/kubelet/kubeadm-flags.env` on **every** node after upgrading kubelet to 1.35+.

### kubeadm-config `kubernetesVersion` stuck at v1.32.9

- **Symptom:** `kubeadm upgrade` / `kubeadm upgrade node` refuses: current version v1.32.9 while API is v1.34+.
- **Cause:** Failed `kubeadm apply` rollbacks or bad ConfigMap patches.
- **Fix:** Replace entire `ClusterConfiguration` from `kubernetes/clustzilla/kubeadm-clusterconfiguration-v1.36.1.yaml` (update version field per hop). Avoid broken regex patches (one patch produced `kubernetesVersion: v  gitVersion: 1.36.1`).

### Wrong API endpoint in kubeconfig

- **Was:** `https://5.223.37.244:443`
- **Now:** `https://5.223.76.164:6443` (control plane node IP)

## Workers

### Drain blocked by CCM PDB

- **Symptom:** `Cannot evict pod ... ccm-hetzner ... violates pod's disruption budget`.
- **Fix:** `kubectl drain ... --disable-eviction` or temporarily remove PDB.

### Loki PVC multi-attach

- **Symptom:** `loki-0` Pending: `Multi-Attach error for volume ... already attached to another node`.
- **Cause:** StatefulSet volume still attached after drain to different node.
- **Fix:** `kubectl delete pod loki-0 -n logging`; wait for volume detach/reattach.

## Addons / storage

### Loki disk full (pre-upgrade incident)

- **Cause:** 10Gi PVC full, retention disabled.
- **Lesson:** Enable retention, larger PVC, reconsider `enableStatefulSetAutoDeletePVC: true`.

## Tooling

| Tool | Version used |
|------|----------------|
| kubectl (local) | 1.36.1 |
| clusterctl | 1.13.2 |
| CAPI (mgmt) | 1.13.2 |
| CAPH | 1.1.4 |

## Checklist for next upgrade

- [ ] etcd snapshot + Helm backup
- [ ] Fix `kubeadm-config` `kubernetesVersion` to **current** API version
- [ ] Run `./scripts/kubeadm-hop.sh v1.X.Y` one minor at a time
- [ ] After each hop: strip `--cloud-provider` from CP manifests if reappears
- [ ] After 1.35+: fix `kubeadm-flags.env` on all nodes
- [ ] Validate `/readyz`, nodes, CNI, CCM, CSI before next hop
- [ ] Do not unpause CAPI MD until Hetzner templates work in `sin`
