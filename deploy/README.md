# Deploy: repeatable Hetzner Kubernetes (CAPI)

Greenfield workflow for a **Hetzner Cloud** workload cluster via **Kind + Cluster API Provider Hetzner (CAPH)**, then the **full-platform** add-on stack (Flannel, CCM, CSI, Kong, monitoring, Argo CD, etc.).

## Prerequisites

- [hcloud CLI](https://github.com/hetznercloud/cli) with API token
- `kubectl`, `helm`, `kind`, `clusterctl` (tested with clusterctl **v1.13.x**)
- SSH key registered in Hetzner Cloud (`SSH_KEY_NAME`)
- Ruby (macOS default) — used to patch KubeadmControlPlane YAML

## Quick start

```bash
cp deploy/env.example deploy/.env
# Edit deploy/.env — set HCLOUD_TOKEN, robot creds, CLUSTER_NAME, machine types

cd deploy
make preflight
make all          # mgmt + capi + cluster + platform
make validate
```

Workload kubeconfig: `output/<CLUSTER_NAME>-kubeconfig.yaml`

Platform add-ons and post-install steps: [docs/components.md](../docs/components.md).

```bash
export KUBECONFIG="$(pwd)/../output/my-cluster-kubeconfig.yaml"
kubectl get nodes
```

## Machine types (Singapore)

Do **not** use `cpx21` / `cpx31` for new CAPI machine rolls in `sin`. Preflight enforces this. Verify with:

```bash
hcloud server-type list
```

Use types that exist for your location (e.g. `cpx32`, `ccx23`). See [docs/upgrade/issues-and-lessons.md](../docs/upgrade/issues-and-lessons.md).

## What gets installed

| Step | Script | Purpose |
|------|--------|---------|
| preflight | `preflight.sh` | Tools, env, server types |
| mgmt | `00-mgmt-kind.sh` | Kind management cluster |
| capi | `01-capi-init.sh` | `clusterctl init`, Hetzner secrets |
| cluster | `02-workload-cluster.sh` | `clusterctl generate cluster`, wait, kubeadm patch |
| platform | `03-platform.sh` | Helm add-ons per `profiles/full-platform.yaml` |
| validate | `04-validate.sh` | Nodes / core checks |
| export | `05-export-snapshot.sh` | CAPI YAML snapshot |

## Kubeadm patch

After the cluster is provisioned, `patch-kubeadm-config.sh` sets `kubelet-preferred-address-types` to **InternalIP first** so `kubectl logs` works without public DNS for node hostnames. Template: [templates/kubeadm-clusterconfiguration.yaml](templates/kubeadm-clusterconfiguration.yaml).

## Secrets

- Never commit `deploy/.env`.
- Rotate tokens if they were ever stored in another repo (e.g. `hetzner-cluster/res/env`).

## Related repo

Operational runbooks and live cluster history remain in [hetzner-cluster](https://github.com/hkandeal/hetzner-cluster). This repo is the **repeatable provisioner** distribution.
