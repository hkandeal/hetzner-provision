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

Behind ingress / TLS: set `server.insecure: "true"` in `argocd-cmd-params-cm` if terminating TLS at Kong, then `kubectl rollout restart deploy/argocd-server -n argocd`. See [Argo CD ingress docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/).

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
