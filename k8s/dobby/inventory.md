# Bella inventory

- Inspected read-only using `karma@bella`, 2026-11-15, Asia/Kolkata.
- No files, workloads, packages, node labels, services or network settings were changed on bella during inspection.
- Architecture: arm64/aarch64. Ubuntu 24.04.4 LTS, kernel 6.17.0-1011-oracle.
- CPU: 2 vCPUs. RAM: 12,506,738,688 bytes, 11.65 GiB. Available RAM at inspection: about 9.75 GiB; this is a changing snapshot.
- Root filesystem: ext4 on `/dev/sda1`, 47,321,268,224 usable bytes, 44.07 GiB. Latest available after cleanup: 28,446,674,944 bytes, 26.49 GiB, up from the earlier 17.67 GiB snapshot. Latest used: 18,857,816,064 bytes (40%). `/srv` is on this filesystem, not a separate data disk.
- `/srv/dobby` does not exist yet.
- Live metrics snapshot: bella 885m CPU, 2,954 MiB memory. Existing Folding@home workload requests 200m CPU/1,700 MiB and permits 800m CPU/3,400 MiB. Dobby may compete with it during builds; no change to that workload is included.
- Kubernetes v1.36.3+k3s1, containerd 2.3.2-k3s2. Nodes: bella and teddy.
- Bella advertises `100.96.156.117`, teddy `100.80.19.125`. Bella also has private interface address `10.0.0.6`. Public/NAT cloud addresses were not independently discovered.
- Node pod ranges: bella `10.42.0.0/24`, teddy `10.42.1.0/24`. Observed Services use `10.43.x.x`, DNS `10.43.0.10`. Confirm configured aggregate service range before deployment.
- k3s config uses `flannel-backend: wireguard-native`. Existing node traffic already uses tailnet IPs. No Tailscale Kubernetes operator pods were present.
- Tailnet suffix: `smelt-gray.ts.net`. Bella's existing name: `bella.smelt-gray.ts.net`.
- Existing classes: `local-path` and `bella-storage-class`. Existing Folding@home PV declares 2 GiB. Dobby uses separate retained local PVs instead of changing either class.
- No NetworkPolicies existed at inspection. Enforcement still needs a live connectivity test.
- `karma` is UID/GID 1002, has a usable user kubeconfig, and cannot run passwordless sudo. Dobby will deliberately use a different in-container identity, 10000:10000, with no host login account.
- Existing high host UIDs include Snap identities. Do not rely on default random user-namespace allocation avoiding them: reserve and verify a separate kubelet subordinate range before launching the sudo-enabled workspace.
- Kernel/runtime version prerequisites for Kubernetes user namespaces are met. Actual idmapped local-PV mounts, AppArmor interaction, sudo and Chromium still require a live smoke test.
- Revised local-PV declaration after cleanup: 16.25 GiB total, split home 3 GiB, workspace 12 GiB, preview-config 256 MiB, relay 1 GiB. This leaves approximately 10.24 GiB beyond the declared budget at the inspection snapshot. This is not a hard disk quota. Leave room for image layers, temporary files and other workloads. Expand storage before sustained multi-project use.
