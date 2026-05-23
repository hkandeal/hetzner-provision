# Bootstrap troubleshooting

## kubectl logs: no such host on node hostname

Apiserver must prefer InternalIP when talking to kubelet. Re-run deploy/scripts/patch-kubeadm-config.sh after upgrades.

## CAPI roll: unsupported location for server type

Update HCLOUD_*_MACHINE_TYPE in deploy/.env; avoid cpx21/cpx31 in sin.

## Worker lost during drain

Pause MachineDeployment before destructive drain. See docs/upgrade/issues-and-lessons.md.

## Kubelet cert expiry

Ensure bootstrap-kubelet.conf on workers; prune stale kubelet-client-*.pem files.
