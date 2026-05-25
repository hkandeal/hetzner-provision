# Platform components

Automated installs run via `deploy/scripts/03-platform.sh` (profile: `deploy/profiles/full-platform.yaml`). Helm values live next to each component under `components/`.

## Automated install order

| Step | Component | Method | Values / manifests |
|------|-----------|--------|-------------------|
| 1 | Flannel CNI | upstream manifest | — |
| 2 | Hetzner CCM | `syself/ccm-hetzner` | secret from `HCLOUD_TOKEN` |
| 3 | Hetzner CSI | upstream manifest | — |
| 4 | metrics-server | upstream manifest | — |
| 5 | CSR approver | `components/csr/*.yaml` | auto-approves kubelet-serving CSRs |
| 6 | cert-manager | `jetstack/cert-manager` | `components/cert-manager/values.yaml` |
| 7 | ClusterIssuer | manifest | `components/cert-manager/cluster_issuer.yaml` |
| 8 | Kong | `kong/kong` | `components/ingress/kong/values.yaml` |
| 9 | Prometheus | `kube-prometheus-stack` | `components/observability/prometheus/values.yaml` |
| 10 | Loki | `grafana/loki` | `components/observability/logging/loki/values_loki.yaml` |
| 11 | Argo CD | `argo/argo-cd` | `components/argocd/values.yaml` |
| 12 | Netdata | `netdata/netdata` | `components/observability/netdata/values.yaml` |

Re-run a single step manually using the same chart and `-f` path as in `03-platform.sh`.

---

## Resource sizing

CPU and memory **requests** and **limits** are set in Helm values for platform control-plane addons (sized for a typical **3× cpx32 worker** cluster). Tune after observing usage with `kubectl top pods`.

| Component | Values file | Workloads |
|-----------|-------------|-----------|
| cert-manager | `components/cert-manager/values.yaml` | controller, webhook, cainjector, startupapicheck |
| Kong | `components/ingress/kong/values.yaml` | proxy, ingress-controller, migrations job |
| Argo CD | `components/argocd/values.yaml` | application-controller (192Mi req), repo-server (64Mi), applicationset (48Mi), server, redis, dex, notifications |
| Netdata | `components/observability/netdata/values.yaml` | parent (192Mi req, 1Gi limit), child (DaemonSet), k8s-state; `sd.child` sidecar already sized |
| Loki | `components/observability/logging/loki/values_loki.yaml` | single-binary, results-cache, canary (`allocatedMemory` drives cache sizing) |

Apply or refresh resources on a **running** workload cluster:

```bash
source deploy/scripts/lib.sh
load_env
use_workload_kubeconfig

helm repo update jetstack kong argo netdata

helm upgrade cert-manager jetstack/cert-manager \
  -n cert-manager -f components/cert-manager/values.yaml

helm upgrade kong kong/kong \
  -n kong -f components/ingress/kong/values.yaml

helm upgrade argocd argo/argo-cd \
  -n argocd -f components/argocd/values.yaml

helm upgrade netdata netdata/netdata \
  -n netdata -f components/observability/netdata/values.yaml
```

Verify rollouts and resources:

```bash
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=180s
kubectl rollout status deployment/kong-kong -n kong --timeout=180s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

kubectl get pods -n cert-manager -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory
kubectl top pods -n cert-manager 2>/dev/null || true
kubectl top pods -n kong 2>/dev/null || true
kubectl top pods -n argocd 2>/dev/null || true
kubectl top pods -n netdata 2>/dev/null || true
```

On a live cluster, prefer **pinned chart version** and **`--reuse-values`** with a resource-only overlay (see `deploy/overlays/platform-resources-*.yaml`) so other settings are not reset.

If pods stay `Pending`, check `kubectl describe pod` for insufficient CPU/memory on nodes and lower requests or add workers.

---

## Post-install: Argo CD

PVCs (optional, before or after first install if not in values):

```bash
kubectl apply -f components/argocd/argocd-repo-server-pvc.yaml
kubectl apply -f components/argocd/argocd-app-controller-pvc.yaml
```

Initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Upgrade:

```bash
helm upgrade argocd argo/argo-cd -n argocd -f components/argocd/values.yaml
```

**Kong ingress:** TLS terminates at Kong; Argo must accept HTTP on the pod. Keep `configs.cm.server.insecure: true` and `configs.params.server.insecure: true` in [`components/argocd/values.yaml`](components/argocd/values.yaml) (or apply [`deploy/overlays/platform-argocd-ingress-fix.yaml`](deploy/overlays/platform-argocd-ingress-fix.yaml)). If the UI loops on redirect, check `argocd-cmd-params-cm` and restart the server. See [Argo CD ingress docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/).

---

## Post-install: Kong (custom image)

`values.yaml` uses `hossamgbm/kong-custom`. Rebuild and push when changing plugins under `components/ingress/kong/plugins/`:

```bash
cd components/ingress/kong/image
docker build --platform=linux/amd64 -t kong-custom:latest .
docker tag kong-custom:latest hossamgbm/kong-custom:<tag>
docker push hossamgbm/kong-custom:<tag>
```

Update the image tag in `components/ingress/kong/values.yaml`, then:

```bash
helm upgrade --install kong kong/kong -n kong -f components/ingress/kong/values.yaml
```

Optional: plugin ConfigMap (if not baked into image):

```bash
kubectl create configmap jwks-oauth-plugin \
  --from-file=components/ingress/kong/plugins/jwks-oauth-plugin -n kong \
  --dry-run=client -o yaml | kubectl apply -f -
```

Hetzner load balancer annotation (region):

```bash
kubectl annotate svc kong-kong-proxy -n kong load-balancer.hetzner.cloud/location=sin
```

Chart reference: [Kong Helm chart](https://github.com/Kong/charts/tree/main/charts/kong)

---

## Post-install: Hetzner CCM

Edit deployment env if you use Robot bare-metal or debug logging:

```bash
kubectl edit deployment -n kube-system -l app.kubernetes.io/name=ccm-hetzner
```

---

## CSR approval

The platform deploys `csr-auto-approver` in `kube-system` (kubelet-serving signer only). Manual approval if needed:

```bash
kubectl get csr
kubectl certificate approve <csr-name>
```

---

## Smoke test

After DNS and cert-manager are ready:

```bash
kubectl apply -f tests/ingress_cert/ping.yaml
```
