# Live preview portal

- One entry point: `https://dobby-previews.smelt-gray.ts.net`.
- Two parts: Homepage provides the tile dashboard; nginx proxies the selected preview to the project's localhost port. nginx runs inside dobby's workspace container, so it can reach `127.0.0.1` listeners directly.
- There is one preview Kubernetes Service and one Tailscale Ingress. No per-preview hostname, public IP, new Service, Ingress or cluster API credential is required.
- The portal is framework-independent. Each project owns its dev server and command; the tile registry only needs its name and port. Vite is one possible server, not the platform.

## First installation

- After rendering and preparing host folders, run on bella:

```sh
sudo bash scripts/seed-preview-config.sh /srv/dobby rendered/homepage
```

- This seeds only missing Homepage files in `/srv/dobby/preview-config`. The same directory is mounted at `/preview-config` inside dobby and `/app/config` inside Homepage.
- The dashboard starts empty; no sample tile pretends to be a running project.

## Agent workflow

1. Start the project's own preview server on an unused localhost port in **3000..5999**, in a named tmux window. Use its normal framework-specific launch command.
2. Inform the portal of the name and port:

```sh
dobby-preview add "Shop redesign" 5173
dobby-preview add "Admin wireframe" 5174
```

3. Open the dashboard and choose a tile. Routes are `/live/5173/` and `/live/5174/`; nginx forwards requests and WebSocket upgrades to the corresponding `127.0.0.1` server inside dobby.
4. The project's own watcher/hot-reload mechanism handles edits. The portal doesn't rebuild projects or copy files. Refresh Homepage after adding tiles if its dashboard data is cached.
5. Remove a tile when finished:

```sh
dobby-preview remove 5173
dobby-preview list
```

- Registration updates only Homepage YAML. It does not create Kubernetes resources, start/stop processes or install dependencies. Re-registering a port updates its tile rather than duplicating it.
- Agents can also edit `/preview-config/services.yaml` directly. `services.example.yaml` shows the format. The small `dobby-preview` helper is configuration glue, not a custom web service.

## Path-prefix compatibility

- One origin serving multiple apps needs a routing discriminator. This configuration uses `/live/PORT/` and preserves that prefix when proxying.
- The project server must support that prefix for its routes and asset URLs. Apps that hardcode root-relative paths, root redirects or cookie paths may need their framework's base-path/proxy setting. A generic proxy cannot transparently fix every possible application's URLs.
- `vite.config.example.js` is one optional example, not a required framework. Retain the project's existing plugins when applying settings. It binds localhost, uses the matching base path, and sends HMR over the private HTTPS origin.
- Other frameworks use their corresponding base-path and WebSocket settings. Validate the initial page, assets, navigation and an actual source edit before marking a preview ready.
- Projects that emit absolute localhost URLs or make browser calls to another localhost API may need an application-side proxy/public-origin setting as well; browser localhost refers to the viewer's device.

## Sessions and recovery

- Open the browser terminal once to create the `dobby` tmux session. A caller operating earlier can create it with `tmux new-session -d -s dobby -c /workspace`.
- Example launch pattern, substituting the project's real command: `tmux new-window -t dobby -n shop-preview 'cd /workspace/shop && npm run dev'`.
- Browser/laptop disconnection does not end tmux work. Container replacement stops running servers; code, credentials and tile configuration remain in host folders.
- No custom auto-discovery, launcher or automatic process-restore daemon is installed. Restart required project servers after container replacement. Tiles can remain stale until removed; unavailable upstreams return a gateway error.
- Multiple previews share the preview browser origin. They are not browser security boundaries. The terminal and Happier stay on separate origins.
- Only ports 3000..5999 are proxied. The terminal on 7681, gateway on 8080, and unrelated administrative ports are excluded.
- Homepage has no mounted source code, agent credentials, runtime socket or Kubernetes API credentials. Its only persistent mount is its own dashboard configuration. nginx shares the workspace's isolation boundary because localhost connectivity requires it to run there.
- There is no saved static gallery in this setup. Each tile represents a running project server.

## Sources

- [Homepage services](https://gethomepage.dev/configs/services/) and [dashboard refresh](https://gethomepage.dev/configs/settings/)
- [Vite base URL](https://vite.dev/config/shared-options#base) and [server settings](https://vite.dev/config/server-options)

## Last updated

- Date: 2026-11-14 23:12 UTC
- Previous commit: [3df6ade](https://github.com/adi-QTPi/ministry/commit/3df6ade)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
