# dobby

- Status: deployment configuration prepared, not deployed or runtime-tested. Bella was inspected read-only over `karma@bella`; see [verified inventory](inventory.md).
- Existing software only: Happier, Claude Code, Codex, CommandCode, ttyd, tmux, Supervisor, Homepage, nginx, and the Tailscale Kubernetes operator. The scripts here only prepare directories, render manifests, load credentials, seed the dashboard configuration and register preview tiles. No custom agent service, UI, or adapter.
- One workspace container contains all agents. A separate relay serves Happier's UI/API; Homepage lists live previews behind nginx. The operator adds its own control and proxy pods.
- Browser access is the normal workflow: Happier chat or a ttyd terminal backed by tmux. Initial pairing can run in that browser terminal; `kubectl exec` remains an administrative fallback. No SSH server is installed in dobby.
- Files under `manifests/` are templates. Apply only individually named rendered files in the order below.
- [Firstmate setup](firstmate/README.md) is included in the initial image and browser-terminal workflow. The native tmux path does not depend on Happier SDK compatibility.

## Three private entry points

- `https://dobby.smelt-gray.ts.net`: Happier chat, sessions, files, approvals and Git review.
- `https://dobby-terminal.smelt-gray.ts.net`: a real terminal inside the same workspace container. ttyd attaches to tmux, so sessions remain running after browser disconnection.
- `https://dobby-previews.smelt-gray.ts.net`: one Homepage dashboard listing multiple live development servers. Selecting a tile opens `/live/PORT/` under this same origin; source changes hot-reload through Vite.
- Kubernetes Services provide the backends. Three Tailscale-class Ingresses provision private HTTPS endpoints. The operator is the controller, not a hostname you access with port numbers.
- A new preview needs a dev server and a dashboard entry, not a new Ingress or URL hostname. Registration is agent-managed YAML configuration; there is no custom port-scanning service.
- [Preview setup and agent workflow](previews/README.md).

## Execution order and server changes

### 1. Inspect bella and the cluster, without changing them

- Confirm the intended kube context, bella's Kubernetes hostname label, architecture, free disk, RAM, CPU, existing workloads, DNS setup, and NetworkPolicy enforcement.
- Record all node addresses, including public addresses. Check actual pod/service CIDRs and any private services using public IPs.
- This bundle supports an IPv4 cluster with ordinary CoreDNS. Dual-stack, NodeLocal DNS, or a different networking arrangement needs policy adjustments before deployment.
- Inspect, from the admin machine:

```sh
kubectl config get-contexts
kubectl --context YOUR_CONTEXT get nodes -o wide
kubectl --context YOUR_CONTEXT get node bella --show-labels
kubectl --context YOUR_CONTEXT get pods -A -o wide
kubectl --context YOUR_CONTEXT get storageclass
kubectl --context YOUR_CONTEXT -n kube-system get service kube-dns
```

- On bella, inspect `df -h`, `free -h`, `uname -m`, and `/etc/rancher/k3s/config.yaml` or the k3s service flags. Do not paste credentials or full kubeconfigs into chat.
- Initial requests total 650m CPU and about 1.4 GiB RAM, excluding Tailscale pods. Workspace limits are 1 CPU and 4 GiB RAM. Tune `manifests/04-workloads.yaml` and the namespace quota to fit actual spare capacity.

### 2. Reserve unprivileged host identities, then prepare folders on bella

- Dobby gets passwordless sudo **inside its container**, with `hostUsers: false` on every dobby pod. Container root maps into kubelet's subordinate host UID/GID range. This is separate from the UID 10000 used for the container's normal user and local-volume inode ownership.
- Do not use karma, opc, ubuntu, or another real host login as the container identity. No host account is created for UID/GID 10000.
- Bella has Snap host identities above UID 65535, so default user-namespace allocation alone is insufficient for your requested non-overlap. The preparation script reserves kubelet's range **16777216 through 23986175**, checking current accounts and subordinate assignments for collisions. Keep this range reserved from future host users/groups as well.
- On bella, review and run the following before creating any user-namespaced pods:

```sh
sudo python3 scripts/configure-userns.py
```

- This creates a non-login `kubelet` system account if missing and adds its subordinate ranges to `/etc/subuid` and `/etc/subgid`, retaining timestamped backups. It requires `getsubids`, already present on bella, and does not change which account runs k3s.
- **A planned `sudo systemctl restart k3s` is required after this configuration.** This restarts the control plane on bella. Check existing workload tolerance and do it before installing dobby; the script does not restart anything automatically. If any user-namespaced pods already exist, the script refuses and a drain/reconfiguration procedure is needed instead.
- No kernel or runtime upgrade is planned: inspected versions meet the documented prerequisites. Idmapped volume mounts must still pass an actual pod test; do not remove `hostUsers: false` to work around startup failures.
- Sudo requires baseline Pod Security, setuid capability and a writable workspace container layer. Relay and Homepage keep read-only roots and disallow privilege escalation. The workspace grants only the baseline capabilities listed in its manifest, without privileged mode or SYS_ADMIN.
- Packages installed with `sudo apt-get` are temporary container changes and disappear when the container is replaced. Put durable system dependencies in the Dockerfile and rebuild. npm/pip/project dependencies installed in home/workspace remain on the host volumes.
- User-installed global npm tools default to `/home/dobby/.local`, already on PATH and stored in bella's home volume. Python virtual environments created under `/workspace` or `/home/dobby` also persist. Neither requires sudo. Downloaded standalone tools can live in `~/.local/bin`. Persistent tools remain architecture-dependent, so keep this workspace on ARM64.
- Example inside dobby: `npm install --global PACKAGE` persists the installed tool; `python3 -m venv /workspace/PROJECT/.venv` persists that environment. Image-managed agent binaries remain under `/opt/agents`; avoid accidentally shadowing those with a second home-installed copy.
- Mounting `/var/cache/apt` would preserve downloaded archives only. Mounting `/var/lib/dpkg` alone would preserve a database that no longer matches installed files. Do not bind `/usr`, `/etc`, and package databases piecemeal to simulate a persistent operating system.
- User namespaces reduce privileges outside the container; they cannot guarantee that an arbitrary kernel exploit will remain unprivileged.

- Prepare the reviewed directories as root on bella. No host agent CLIs or container runtime are installed:

```sh
sudo bash scripts/prepare-bella.sh /srv/dobby
```

- The resulting host paths are:

```text
/srv/dobby/
  home/        UID 10000, private; agent logins, sessions, Git and gh settings
  workspace/   UID 10000, private; repositories, worktrees, installed project deps
  preview-config/ UID 10000, private; Homepage config and agent-maintained preview tiles
  relay/       UID 1000, private; Happier database and attachment storage
  admin/       root only; relay master secret and Tailscale OAuth credentials
```

- These are dedicated dobby folders. Do not mount bella's real home, `/`, kubeconfig, runtime sockets, or host SSH credentials.
- Storage declarations are home 3 GiB, workspace 12 GiB, preview dashboard configuration 256 MiB, relay 1 GiB. The local PV capacities declare 16.25 GiB in total. **They do not reserve disk or enforce per-folder limits.** Provision enough space, configure filesystem quotas if needed, and arrange an external backup. Bella was rechecked after cleanup and has 26.49 GiB free. This leaves about 10.24 GiB beyond the declared data budget for image layers, temporary builds and other workloads. Monitor actual disk consumption before adding larger projects.
- If changing the base path, pass that same path to preparation/secret scripts and `BASE_DIR` in settings.

### 3. Configure Tailscale access and create admin secrets

- Enable MagicDNS and HTTPS certificates for the tailnet. Existing Tailscale on bella remains independent of these Kubernetes service identities.
- Copy `settings.env.example` to ignored `settings.env`, fill the tailnet identity and DNS suffix, actual node/CIDR values, and other deployment values.
- Merge the fragment in `tailscale/policy.hujson` into the existing policy, substituting your identity. Do not replace the tailnet policy. Existing broad grants/ACLs are additive and must not already grant everyone access to `tag:dobby`.
- Create the operator OAuth client tagged `tag:dobby-operator`, with write access to Devices/Core, Keys/Auth Keys, and General/Services as required by the current operator docs.
- On bella, create the private secret files. Existing files are retained:

```sh
sudo python3 scripts/create-admin-secrets.py --base /srv/dobby
```

- This creates `admin/relay.env` and `admin/tailscale.env` without printing their contents. Keep the relay master secret with the database backups; do not regenerate it during ordinary restarts.

### 4. Build and publish with GitHub Actions

- The repository workflow `.github/workflows/dobby-image.yml` builds on GitHub-hosted ARM64 and AMD64 runners, not on bella. Each architecture is built natively and smoke-tested before publishing the shared multi-architecture tag.
- Pushes to `main` changing `k8s/dobby/image/**` or the workflow itself publish to `ghcr.io/adi-qtpi/dobby`. PRs build/test without publishing. Manual runs on `main` can publish too.
- CI uses the built-in `GITHUB_TOKEN` with package-write permission. No personal registry token, registry login on bella or host Docker service is needed to build/publish.
- Published references: `:main`, `:sha-COMMIT`, and the immutable multi-architecture digest printed in the publish job summary. Put that digest in `WORKSPACE_IMAGE`. Kubernetes automatically selects ARM64 for bella and AMD64 for an x86 node.
- A newly published GHCR package may initially be private. Make the dobby package public for anonymous node pulls, or provision a dedicated read-packages pull Secret and add `imagePullSecrets` before deployment. CI login does not give k3s registry credentials.
- The image includes pinned agents, development tools, browser terminal, nginx and Firstmate's toolchain. First boot seeds the persistent Firstmate checkout without overwriting existing state.
- The image root/base digests and direct tool versions are pinned; Debian package repositories and transitive npm ranges mean this is not a fully reproducible supply-chain lock. Tool updates require a rebuild.
- Relay and Homepage remain pinned upstream images. Happier currently documents preview image publication; test the pinned relay/CLI combination before regular use.

### 5. Render and review deployment files locally

- Requires Python 3 and PyYAML. If missing, use a local virtual environment and `pip install PyYAML`.
- Finish `settings.env`, confirm the cluster values, then set `CONFIG_VERIFIED=yes`.

```sh
python3 scripts/render.py
```

- Rendering checks required values and image digests, inserts excluded cluster/node CIDRs, and writes ignored `rendered/` files. It does not contact Kubernetes.
- Review the rendered manifests and policy fragment. Set the intended context explicitly in this shell:

```sh
export DOBBY_CONTEXT=YOUR_CONTEXT
```

### 6. Add Kubernetes resources and the Tailscale operator

- Label bella for scheduling. This uses the scheduler and local-volume affinity, not `spec.nodeName`:

```sh
kubectl --context "$DOBBY_CONTEXT" label node bella dobby.workloads/enabled=true
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/00-namespace.yaml
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/01-storage.yaml
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/02-config.yaml
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/03-network.yaml
kubectl --context "$DOBBY_CONTEXT" create namespace tailscale --dry-run=client -o yaml | kubectl --context "$DOBBY_CONTEXT" apply -f -
```

- Secret import must run **on bella**, because these paths exist there. `karma` already has a working kubectl context on bella. Use Bash with pipefail for the commands below; `sudo` reads only the root-owned source file. Passwordless sudo is unavailable, so run `sudo -v` first in that admin session. Confirm that context targets this cluster. Do not copy admin files into dobby's home:

```sh
set -o pipefail
sudo -v
sudo cat /srv/dobby/admin/relay.env | kubectl -n dobby create secret generic dobby-relay \
  --from-env-file=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
sudo cat /srv/dobby/admin/tailscale.env | kubectl -n tailscale create secret generic operator-oauth \
  --from-env-file=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
```

- These secrets also exist in Kubernetes after import. Their source files stay root-only on bella. The relay Secret is supplied only to the relay; the operator credentials are supplied only to the operator.
- Before deploying Homepage, seed missing dashboard files on bella with `sudo bash scripts/seed-preview-config.sh /srv/dobby rendered/homepage`. The rendered directory must be available there; the script preserves existing files.
- Install the operator from the admin machine, using the chart version selected in settings (initial pin shown):

```sh
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update tailscale
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  --kube-context "$DOBBY_CONTEXT" --namespace tailscale \
  --version 1.104.7 --values rendered/tailscale-values.yaml --wait
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/05-services.yaml
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/04-workloads.yaml
kubectl --context "$DOBBY_CONTEXT" apply -f rendered/06-ingress.yaml
kubectl --context "$DOBBY_CONTEXT" -n dobby get pods,pvc,ingress -o wide
```

- This installs operator CRDs, RBAC, its Deployment, an IngressClass, and ingress proxies in `tailscale`. They have infrastructure privileges outside dobby's baseline namespace.
- Dobby adds three Deployments, four internal ClusterIP Services, three private HTTPS Ingresses, four retained local PV/PVC pairs, ConfigMaps, a ServiceAccount without API credentials, a quota, and NetworkPolicies.
- No public NodePorts, SSH server, API-server proxy, subnet router, exit node, or Funnel are configured.

### 7. Create the Happier account and pair dobby

- Open `https://dobby.YOUR_TAILNET.ts.net` while connected to Tailscale. Create a device-key account and save its recovery secret securely, outside the repository.
- Open the browser terminal and run `happier auth login`, then approve the pairing link in the signed-in Happier browser. Administrative fallback:

```sh
kubectl --context "$DOBBY_CONTEXT" -n dobby exec -it deployment/dobby-workspace -- happier auth login
```

- Open the pairing link in the authenticated browser and approve it. The browser terminal is available immediately. Supervisor runs ttyd independently while the Happier worker waits for valid authentication, then starts the daemon.
- The canonical URL is the private HTTPS URL; CLI/daemon backend traffic uses the internal relay Service. This avoids requiring tailnet DNS or a Tailscale client inside dobby.
- Confirm the workspace appears online. After account creation and pairing work, set `AUTH_ANONYMOUS_SIGNUP_ENABLED` to `"false"` in `manifests/02-config.yaml`, render again, apply the rendered ConfigMap, and restart only the relay.
- Existing clients must restore/link the same account, not create another account. Verify recovery on a second browser before disabling signup.

### 8. Authenticate agents and configure Git in the mounted home

- Run these in dobby's browser terminal. Administrative fallback: Every home-directory write lands directly in `/srv/dobby/home` on bella:

```sh
kubectl --context "$DOBBY_CONTEXT" -n dobby exec -it deployment/dobby-workspace -- bash
```

- In that shell, authenticate the native tools:

```sh
claude auth login
codex login --device-auth
cmd login
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR VERIFIED GITHUB EMAIL"
git config --global init.defaultBranch main
```

- Follow printed browser/device flows. Codex device authorization may need enabling in account settings. For Claude/CommandCode, use the CLI's offered headless method if a browser callback is unavailable. Don't forward a login callback unless that specific flow needs it.
- An alternative for CommandCode is its account API key in the optional token file below. This authenticates CommandCode itself; it does not require configuring separate model-provider API billing.
- For unattended GitHub access, prefer a repository-scoped fine-grained PAT over an unrestricted personal token. Put `GH_TOKEN` in the token file instead of using broad `gh` OAuth, and still run `gh auth setup-git`. This bundle uses HTTPS Git; outbound SSH port 22 is not allowed.
- Protect default branches and require checks. Dobby may push task branches and create PRs with `gh pr create --draft`; it has whatever GitHub permissions its token grants.

#### One persistent location for all logins

```text
/srv/dobby/home/
  .claude/                   Claude auth/settings/sessions as managed by its CLI
  .claude.json               Claude settings when used by the installed CLI
  .codex/                    Codex auth.json/config/session state
  .commandcode/              CommandCode auth.json/settings/session state
  .happier/                  Happier identity, credentials and runtime state
  .config/gh/                GitHub CLI hosts/config files
  .config/dobby/credentials.env  Optional COMMAND_CODE_API_KEY and/or GH_TOKEN
  .gitconfig                 Git identity and credential-helper configuration
```

- Native CLIs manage their own formats and refresh tokens. There is no shared universal auth file. Dobby mounts this home directly; there is no second copy to synchronize.
- To preseed a supported token on bella, create `home/.config/dobby/credentials.env` using the example in this folder. Use literal `KEY=value` without quotes; owner `10000:10000`, mode `0600`. The startup script reads only `COMMAND_CODE_API_KEY` and `GH_TOKEN`, without executing shell text.
- Token-file changes take effect after restarting the workspace, which interrupts active work. Native CLI login files can be updated through the CLI without rebuilding the image.
- A new `kubectl exec` process does not inherit variables exported by the running entrypoint. Token-file credentials are inherited by ttyd terminals and Happier-launched agents/terminals; use a browser terminal for token-based GitHub setup after restart. Native login-file credentials work from either terminal.
- `GH_TOKEN` overrides GitHub CLI's saved login. Clear it if switching to `gh auth login`. Likewise, a CommandCode key overrides its saved login.
- Keep root-only operator/relay credentials under `/srv/dobby/admin`; do not put them in this mounted home. Agents can read or modify all credentials in their own home, so scope them accordingly.
- The host need not install any of these CLIs. Do the actual logins inside dobby, so the native CLI writes the correct mounted files. To seed files from bella, use sudo to place them under this directory with the stated ownership. Do not create a host login for UID 10000 or point dobby at your normal workstation/server home.

### 9. Configure the three agents in Happier

- Select the dobby machine and a folder under `/workspace`. Use built-in Claude and Codex backends, retaining each provider's native subscription login.
- Add CommandCode under Settings, AI & Agents, AI backends, Custom backends: command `cmd`, arguments `["acp"]`. Authenticate it first using the native CLI or token file.
- Custom ACP is experimental. Verify tool execution, images, questions, session reopening and authentication before relying on it. Do not build an adapter if it fails; keep CommandCode usable through Happier's embedded terminal while evaluating the integration.
- Select the desired full-access permission mode in each supported agent interface. Container policy still applies. Start one agent at a time per checkout; use distinct worktrees for parallel edits.

### 10. Use Firstmate, the browser terminal and the preview dashboard

- Firstmate is included from the first deployment. After provider/GitHub login, run `dobby-firstmate setup` once, then `dobby-firstmate` in the browser terminal. The default lead is native Claude Code; Codex and CommandCode are available to workers. [Firstmate setup and acceptance checks](firstmate/README.md).
- Firstmate's operational home is `/workspace/firstmate`, persisted in bella's workspace folder. The image contains a pinned seed; existing operational checkouts are not overwritten or automatically updated. No agent session starts at container boot.


- Open `https://dobby-terminal.smelt-gray.ts.net`. It provides the actual dobby shell, with the same mounted home, credentials, tools and container-local sudo. Native Claude Code, Codex, CommandCode and Firstmate can run directly here.
- ttyd, nginx and the Happier daemon run under Supervisor inside the same workspace container. A failed Happier login does not prevent terminal access. tmux preserves running terminal sessions between browser connections; container replacement still stops them.
- The browser terminal runs native Firstmate/agent TUIs directly, independently of Happier SDK integration. The terminal is a full-control endpoint. Only the intended tailnet identity should have access. ttyd checks WebSocket origins, exposes no URL-argument execution and has no public listener outside the selected Tailscale Service. Multiple browser clients share the same `dobby` tmux session.
- Start each project's own server on localhost at a free port in 3000..5999, in a named tmux window. Register it with `dobby-preview add "Project name" PORT`. No Kubernetes resource is created by registration. The project needs compatible `/live/PORT/` base-path settings; see the framework-independent portal guide.
- Open `https://dobby-previews.smelt-gray.ts.net` and choose the desired preview. Refresh Homepage after adding tiles if needed; Vite handles subsequent source-edit hot reload.
- [Exact setup, Vite example, registry format and recovery limits](previews/README.md). Homepage and nginx are existing services; the registration helper only updates dashboard YAML. No custom dashboard, scanner or launcher is required. Other frameworks need compatible path-prefix/asset/WebSocket settings.
- Playwright/Chromium remains available inside dobby for visual checks. Its sandbox compatibility still needs a live test; don't enable privileged mode to bypass errors.

### 11. Verify independence, isolation and recovery

- Start a disposable task, disconnect the laptop, and reconnect from another device. Confirm progress happened on dobby and files exist under bella's `/srv/dobby/workspace`.
- Test each agent reading/writing a scratch repository, provider login reuse, GitHub clone/push/draft PR, image feedback, and previews. Use an expendable branch/repository for the first push.
- From the workspace, verify public HTTPS and the internal relay work. Verify attempts to reach a known unrelated pod/service, homelab private address, metadata endpoint and Kubernetes API fail or are unauthorized as appropriate. Test public node IPs too, not only RFC1918 addresses.
- Policies allow public HTTP/HTTPS, rather than domain-allowlisting providers. Untrusted code can still exfiltrate mounted credentials over permitted internet access. CoreDNS is trusted infrastructure, not an anti-exfiltration boundary.
- Kubernetes NetworkPolicy has node-origin/host-traffic exceptions and CNI-dependent behavior. **It does not guarantee isolation from every host-local listener.** Do not describe this as protection against container/kernel escape. If host-listener reachability is unacceptable, add reviewed host firewall/CNI host-policy rules after discovering actual interfaces and addresses.
- No runtime socket, host directories beyond the four dedicated volumes, kubeconfig, API token or host root access is granted to the workspace. Sudo is intentionally permitted only inside its user namespace.
- In a disposable idle session, restart the workspace and verify files, identity and provider logins persist. Running processes stop; saved transcripts may resume only where the backend supports it. No automatic task replay or guaranteed crash continuation is implemented.
- Inspect `/proc/self/uid_map` in each dobby pod and verify all host-side IDs fall within the reserved range. Run `sudo -n id` inside the workspace and confirm it reports container UID 0. Verify normal host files remain inaccessible and the actual host mapping is not karma/opc/root. These are required acceptance checks, not something static manifests can prove.
- The workspace runs Supervisor as its container process, keeping ttyd, nginx and the Happier wrapper independently supervised. It has no relay-dependent liveness probe, so transient provider outages don't deliberately trigger restarts of active agents. Failure of the container process still triggers Kubernetes restart; Supervisor handles its child processes.
- Schedule encrypted, off-bella backups with an existing backup tool. Include workspace, home, preview-config, admin secrets and a consistent relay snapshot. Stop the relay for a filesystem copy or use SQLite's backup facility; don't copy just a live database file and ignore its WAL. A mounted folder alone is not a backup.

## Maintenance and removal

- Rebuild/pin tool images explicitly. Avoid floating image tags and in-place global tool updates inside the workspace.
- Stop active tasks before upgrades. Single replicas and local disk intentionally trade availability for simplicity. If bella is down, dobby is down.
- To stop compute while retaining data: scale the three Deployments to zero. For removal, delete Ingresses while the operator is still available to clean up tailnet devices, then delete workloads/services/configuration. Only uninstall the operator if no other workloads use it.
- Do not delete `/srv/dobby`, PVs or PVCs as a routine uninstall step. `Retain` leaves data for deliberate recovery; a deleted claim may require manual PV rebinding. Keep admin secrets and account recovery material with backups.

## Upstream references

- [ttyd browser terminal](https://github.com/tsl0922/ttyd)
- [Homepage dashboard](https://gethomepage.dev/)
- [Happier containers and relay](https://docs.happier.dev/self-hosting/docker)
- [Happier daemon lifecycle](https://docs.happier.dev/apps/daemon)
- [Happier custom ACP](https://docs.happier.dev/agents/custom-acp)
- [CommandCode ACP](https://commandcode.ai/docs/acp) and [headless auth](https://commandcode.ai/docs/headless)
- [Codex authentication](https://learn.chatgpt.com/docs/auth?surface=cli)
- [Tailscale operator installation](https://tailscale.com/docs/kubernetes-operator/install-operator)
- [Tailscale private Ingress](https://tailscale.com/docs/kubernetes-operator/ingress)
- [Kubernetes user namespaces](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/)
- [Kubernetes local volumes](https://kubernetes.io/docs/concepts/storage/volumes/#local)

## Last updated

- Date: 2026-11-14 23:12 UTC
- Previous commit: [3df6ade](https://github.com/adi-QTPi/ministry/commit/3df6ade)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
