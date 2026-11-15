# Live preview portal

- Public entry point: `https://hq-previews.YOUR_DOMAIN`; email login: `https://hq-preview-auth.YOUR_DOMAIN`.
- Pangolin and Traefik/Badger authenticate viewers before nginx can reach Homepage or a project's localhost port. All four processes run inside dobby's workspace image; Homepage remains a separate pod.
- There is one preview Kubernetes Service and one Tailscale Ingress. No per-preview hostname, public IP, new Service, Ingress or cluster API credential is required.
- The portal is framework-independent. Each project supplies its dev server command and working directory; registration creates a Supervisor service and a dashboard tile. Vite is one possible server, not the platform.

## First installation

- After rendering and preparing host folders, run on bella:

```sh
sudo bash scripts/seed-preview-config.sh /srv/dobby rendered/homepage
```

- This seeds only missing Homepage files in `/srv/dobby/preview-config`. The same directory is mounted at `/preview-config` inside dobby and `/app/config` inside Homepage.
- The dashboard starts empty; no sample tile pretends to be a running project.

## Email access

- On first container startup, the entrypoint creates missing files under `/home/dobby/.config/dobby/pangolin/`. This is the persistent home volume, separate from the Homepage configuration mount. Existing files are preserved.
- SSH into dobby and fill in the two files:

```sh
ssh dobby
vi ~/.config/dobby/pangolin/settings.yaml
vi ~/.config/dobby/pangolin/allowed-emails.txt
dobby-pangolin check
```

- `settings.yaml`: set `preview_url` and `auth_url` to the two public HTTPS origins on your domain. Fill in SMTP host, username, password and sender address. Use implicit TLS (`secure: true`, port 465); SMTP certificates are verified. The Kubernetes policy permits public SMTP on 465. A different SMTP port requires an explicit policy change.
- `allowed-emails.txt`: one exact email address per line. Blank lines and lines starting with `#` are ignored. No wildcard domains. The initial allowlist is empty and denies everyone.
- Startup automatically provisions a private administrator, a Dobby organization, and the email-only preview resource through upstream Pangolin's CLI/API. Viewers need no Pangolin account and no Google/OAuth login. Generated administrator credentials and the signing secret live in `admin.json`, mode 0600. Keep that file and `runtime/db/` with the persistent home; never delete or hand-edit them to rotate credentials.
- The gateway stays locked with HTTP 503 until settings are valid and at least one email is approved. The helper checks file changes every five seconds. Email edits apply automatically; settings edits restart the auth processes through Supervisor. Invalid edits or failed synchronization lock the gateway.
- Browser flow: open previews, enter an approved email, receive Pangolin's single-use code, enter it, then browse using the authenticated browser cookie. The configured session duration defaults to 24 hours. All `/live/PORT/` paths, assets and WebSocket handshakes pass through the same gate.
- An allowlist update may revoke existing sessions. Already open WebSockets can remain connected until they close; removal prevents fresh authenticated requests after the auth cache expires. For immediate disconnection, restart `preview-gateway` after removing access.
- Preview tiles use relative `/live/PORT/` links, so they stay on the hostname used to open the dashboard. Re-registering a legacy absolute tile converts it without creating a duplicate. `preview_url` remains the configured public origin for the login gate.
- Apply the updated public Caddy configuration: both `hq-previews` and `hq-preview-auth` proxy to the existing Tailscale preview endpoint while preserving the public Host header. No IITR IP restriction remains. Configure both public DNS records. The private `.ts.net` hostname is an upstream transport address; it does not bypass the public hostname authentication gate.
- Deploy the new workspace image **and** the updated nginx ConfigMap together, restart the workspace, and apply the SMTP NetworkPolicy. Updating only the image leaves the previous unauthenticated nginx configuration in place. Publishing/building an image alone does not deploy these changes.
- Only `/healthz` bypasses authentication; it returns a constant readiness response with no preview data. The unauthenticated nginx upstream listens on loopback port 6080, Traefik on loopback 6081. Pangolin's internal ports 6100..6104 are outside the 3000..5999 preview range and have no public Service. No Docker socket or tunneling service is required.
- Traefik downloads its pinned Badger plugin over HTTPS on startup. If loading or authentication fails, previews remain inaccessible. The wrapper only seeds configuration and applies allowlists; OTPs, rate limiting, sessions and cookies belong to upstream Pangolin/Badger.

## Agent workflow

1. Install the project dependencies and choose a free localhost port in **3000..5999**. Stop any manually launched server on that port before handing it to Supervisor.
2. Register the project with its foreground start command and working directory:

```sh
dobby-preview add "Shop redesign" 5173 --directory /workspace/shop \
  --command 'npm run dev -- --host 127.0.0.1 --port 5173'
dobby-preview add "Admin wireframe" 5174 --directory /workspace/admin \
  --command 'npm run dev -- --host 127.0.0.1 --port 5174'
```

3. Open the dashboard and choose a tile. Routes are `/live/5173/` and `/live/5174/`; nginx forwards requests and WebSocket upgrades to the corresponding `127.0.0.1` server inside dobby.
4. The project's own watcher/hot-reload mechanism handles edits. The portal doesn't rebuild projects or copy files. Refresh Homepage after adding tiles if its dashboard data is cached.
5. Remove the preview when finished. This stops its managed process group and deletes its saved service and tile:

```sh
dobby-preview remove 5173
dobby-preview list
```

- Registration starts a `preview-PORT` Supervisor program before publishing its tile. Each process gets `PORT` and `DOBBY_PREVIEW_PORT`. The command must stay in the foreground, bind localhost and use the matching port and `/live/PORT/` prefix. Registration does not install dependencies or create Kubernetes resources.
- `--directory` defaults to the current directory. `--command` is required and parsed as argument words without shell expansion. Use an explicit `bash -lc '...'` command if shell syntax is needed. Keep credentials out of command arguments.
- Re-registering an unchanged command updates the tile without restarting a healthy process. Changing the command or directory restarts only that preview. Failed startup restores the previous service and tile. A running process is not a guarantee of HTTP readiness; check the actual preview.
- Control a service with `supervisorctl -c /etc/dobby-supervisord.conf status preview-5173` or `restart preview-5173`. Logs are in `~/.config/dobby/previews/preview-5173.log`, rotated at 1 MiB with three backups.
- Existing tile-only previews are not automatically adopted. Re-register them with their start command to enable management.
- Editing `/preview-config/services.yaml` directly changes tiles only; it does not create or modify managed services. Use `dobby-preview add/remove` to keep tiles and services together. `services.example.yaml` shows the tile format.

## Path-prefix compatibility

- One origin serving multiple apps needs a routing discriminator. This configuration uses `/live/PORT/` and preserves that prefix when proxying.
- The project server must support that prefix for its routes and asset URLs. Apps that hardcode root-relative paths, root redirects or cookie paths may need their framework's base-path/proxy setting. A generic proxy cannot transparently fix every possible application's URLs.
- `vite.config.example.js` is one optional example, not a required framework. Retain the project's existing plugins when applying settings. It binds localhost, uses the matching base path, and sends HMR over the private HTTPS origin.
- Other frameworks use their corresponding base-path and WebSocket settings. Validate the initial page, assets, navigation and an actual source edit before marking a preview ready.
- Projects that emit absolute localhost URLs or make browser calls to another localhost API may need an application-side proxy/public-origin setting as well; browser localhost refers to the viewer's device.

## Sessions and recovery

- Open the browser terminal once to create the `dobby` tmux session. A caller operating earlier can create it with `tmux new-session -d -s dobby -c /workspace`.
- Use tmux for agent sessions and interactive work. Use `dobby-preview add` for preview servers; do not launch the same server in tmux as well.
- Browser/laptop disconnection does not end tmux work or managed previews. Container replacement stops processes; Supervisor starts saved preview services again when the workspace starts. The project directory and dependencies must still exist.
- Service definitions, start commands and rotating logs persist under `~/.config/dobby/previews/`, separate from Homepage's configuration mount. Supervisor restarts crashed servers and restores saved services on startup. Servers that repeatedly fail startup enter FATAL; inspect their logs and fix/re-register them. Unavailable upstreams return a gateway error.
- Multiple previews share the preview browser origin. They are not browser security boundaries. The terminal and Happier stay on separate origins.
- Only ports 3000..5999 are proxied. The terminal on 7681, gateway on 8080, and unrelated administrative ports are excluded.
- Homepage has no mounted source code, agent credentials, runtime socket or Kubernetes API credentials. Its only persistent mount is its own dashboard configuration. nginx shares the workspace's isolation boundary because localhost connectivity requires it to run there.
- There is no saved static gallery in this setup. Each tile represents a running project server.

## Sources

- [Supervisor program configuration](https://supervisord.org/configuration.html#program-x-section-settings)
- [Homepage services](https://gethomepage.dev/configs/services/) and [dashboard refresh](https://gethomepage.dev/configs/settings/)
- [Vite base URL](https://vite.dev/config/shared-options#base) and [server settings](https://vite.dev/config/server-options)

## Last updated

- Date: 2026-11-15 21:11 UTC
- Previous commit: [7da0766](https://github.com/adi-QTPi/ministry/commit/7da0766)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
