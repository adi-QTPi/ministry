# Herdr on Dobby

- Dobby uses **Herdr TUI 0.9.1**, matching the laptop's `herdr` client. Herdr Desktop is a separate product using `herdr-core`; these instructions do not configure it.
- `image/install-herdr.sh` installs the native ARM64/AMD64 release with a pinned SHA-256 checksum. Upgrade the installer and client deliberately, rather than running an in-place updater over the image-managed binary.
- Supervisor starts `herdr server` as UID/GID 10000 in `/workspace`. It restarts a failed server. No provider agent starts automatically.
- Herdr's default configuration, session metadata and logs live under `/home/dobby/.config/herdr`, on the retained home volume. Repositories and worktrees live under `/workspace`.
- Laptop disconnects and laptop sleep leave remote panes running. Pod replacement, node reboot and server crashes terminate running programs. Saved layout/history are not a running-process backup; resume agents explicitly after replacement.

## Connect from the laptop

The existing OpenSSH alias is:

```sshconfig
Host dobby
    HostName dobby-shell.smelt-gray.ts.net
    User dobby
    IdentityFile ~/.ssh/portkey
```

`dobby-shell` is the **container's native Tailscale SSH identity**, not Bella's host login and not a Kubernetes HTTPS Ingress. Tailscale's persisted state is `/home/dobby/.config/dobby/tailscale/tailscaled.state`. Supervisor runs userspace `tailscaled` inside the pod, without host networking, TUN or NET_ADMIN. The logged-in identity, SSH enablement and tailnet policy must permit this connection. Never commit Tailscale state, host keys or login tokens.

```sh
ssh dobby 'id; herdr --version'
herdr machine add dobby --label Dobby
herdr
```

Select **Dobby** in the machine sidebar. Alternatively attach directly with `herdr --remote dobby`. The remote default session is shared by these entry points. Do not run Herdr inside tmux merely to obtain persistence; its server already keeps panes alive.

New agents launched in Dobby's Herdr panes use the existing container's files, dependencies and provider logins. Existing Happier/tmux processes are not imported. Start new sessions through Herdr or explicitly resume the relevant provider session there. Herdr does not itself grant YOLO permissions; choose the agent's permission mode deliberately.

## Verify and maintain

```sh
ssh dobby 'herdr status server --json'
kubectl -n dobby exec deployment/dobby-workspace -- \
    supervisorctl -c /etc/dobby-supervisord.conf status
```

- Healthy status reports `running: true`; the CLI can exit successfully even when it reports `running: false`.
- Keep `hostUsers: false`, UID 10000, retained home/workspace volumes and no mounted host/runtime credentials. Adding Herdr does not require broader container privileges or network policy access.
- Tailscale SSH ACLs control access to the workspace. No public SSH listener or Herdr TCP API is required. The separately installed temporary OpenSSH daemon is unnecessary for the native Tailscale path and disappears on image replacement.
- Before image rollout, record the previous immutable image digest and expect active tasks to stop. Set `WORKSPACE_IMAGE` to the tested published digest. Roll out the workspace only; relay and preview dashboard do not need replacement.
- Changing the image does not rotate the persisted Tailscale identity or Herdr configuration. If the tailnet device is removed or its login expires, reauthenticate it through the browser terminal before reconnecting.

## Last updated

- Date: 2026-11-15 01:32 UTC
- Previous commit: [a738af3](https://github.com/adi-QTPi/ministry/commit/a738af3)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
