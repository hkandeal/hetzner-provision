<p align="center">
  <img src="docs/assets/hetzner-cloud.svg" alt="Hetzner Cloud" width="120"/>
</p>

<h1 align="center">hetzner-provision</h1>

<p align="center">
  <strong>Repeatable production-style Kubernetes on Hetzner Cloud</strong><br/>
  Kind · Cluster API (CAPH) · kubeadm · Helm platform stack
</p>

<p align="center">
  <a href="deploy/README.md">Quick start</a> ·
  <a href="docs/upgrade/issues-and-lessons.md">Lessons learned</a> ·
  <a href="https://console.hetzner.cloud/">Hetzner Console</a>
</p>

---

## What this project does

**hetzner-provision** is a distribution repo for standing up a new Hetzner Cloud Kubernetes cluster end-to-end:

1. **Bootstrap** a local Kind management cluster and install Cluster API with the Hetzner provider (CAPH).
2. **Provision** a workload cluster (control plane + workers) via `clusterctl`, with guardrails for Singapore (`sin`) server types and kubeadm settings that work in production (e.g. `InternalIP` for `kubectl logs`).
3. **Install** a curated **full-platform** profile: networking, Hetzner CCM/CSI, cert-manager, Kong, Prometheus, Loki, Argo CD, Netdata, and CSR auto-approval.

It packages operational knowledge from the live [hetzner-cluster](https://github.com/hkandeal/hetzner-cluster) (clustzilla) repo into scripts you can run again for greenfield clusters—without copying secrets or cluster-specific exports.

## Repository layout

```
deploy/              Makefile + scripts — start here
  profiles/          full-platform.yaml (addon order)
  templates/         kubeadm ClusterConfiguration patch
components/          Helm values; see docs/components.md (only what the profile uses)
docs/
  assets/            Hetzner Cloud logo (README)
  upgrade/           Upgrade issues & runbook excerpts
  troubleshoot/      Bootstrap troubleshooting
tests/               Optional ingress/TLS smoke test (ping.yaml)
output/              Generated kubeconfigs (gitignored)
```

## Quick start

```bash
cp deploy/env.example deploy/.env
# Edit deploy/.env — HCLOUD_TOKEN, SSH paths, CLUSTER_NAME, machine types

cd deploy
make preflight
make all          # mgmt → CAPI → cluster → platform
make validate
```

Workload kubeconfig: `output/<CLUSTER_NAME>-kubeconfig.yaml`

Details: [deploy/README.md](deploy/README.md)

## Platform components (automated)

| Layer | Components |
|-------|------------|
| Cluster | Flannel, Hetzner CCM, Hetzner CSI, metrics-server, CSR approver |
| Ingress & TLS | cert-manager, Kong (custom image in values) |
| Observability | kube-prometheus-stack, Loki, Netdata |
| GitOps | Argo CD |

Helm values live under `components/` (e.g. `cert-manager/values.yaml`, `ingress/kong/values.yaml`). Kong custom plugins and image build files are kept for the `hossamgbm/kong-custom` image referenced in Kong values.

## Design choices

- **CAPI + kubeadm** on Hetzner Cloud — not Terraform/k3s.
- **Cloud-only workers** by default (no bare-metal Robot pool unless you extend templates).
- **Preflight** rejects `cpx21` / `cpx31` in `sin` for new machine rolls; use types like `cpx32` / `ccx23`.
- **Secrets** stay in `deploy/.env` (never committed).

## Related repository

[hetzner-cluster](https://github.com/hkandeal/hetzner-cluster) — live cluster ops, upgrades, troubleshooting, and historical exports.
