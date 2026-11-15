# Firstmate on dobby

- Firstmate is part of the initial dobby deployment, accessed through the native browser terminal and tmux. Happier remains an independent chat interface for ordinary agent sessions.
- No separate Firstmate Deployment, Service, hostname, volume, host privilege or custom adapter is required.
- Container builds and live agent supervision have not yet been tested. The image draft includes the tools; this is not a claim that dobby is already deployed.

## Included in the image

- [Firstmate](https://github.com/kunchenguid/firstmate/tree/427056c4181c41074ad24f051f79919330df0fa5), pinned to `427056c4181c41074ad24f051f79919330df0fa5`.
- Existing Claude Code, Codex, CommandCode, Node, Git, gh and tmux.
- Treehouse 3.1.8 and no-mistakes 1.106.1, using checksum-verified native ARM64/AMD64 release archives.
- gh-axi 0.1.51, chrome-devtools-axi 0.1.46, tasks-axi 0.2.6 and quota-axi 0.1.69, pinned npm packages.
- Playwright Chromium is already included for browser checks. Native browser-tool configuration and operation still need a live acceptance test.
- Firstmate's optional presentation tools, remote secondmates and social/voice relays are not enabled.

## Persistence

- The image stores a clean source checkout under `/opt/firstmate`.
- On first boot, `dobby-seed-firstmate` copies it into `/workspace/firstmate` and selects the tmux backend. It copies files only; it does not run upstream instructions, bootstrap, hooks or agents.
- That directory corresponds to `/srv/dobby/workspace/firstmate` on bella and contains Firstmate's code, operational state, project registry, briefs and project checkouts.
- Existing directories are never overwritten, reset or automatically pulled. Rebuilding the image does not silently upgrade an established operational checkout; update that checkout deliberately after saving work.
- Provider logins, Git/GitHub credentials and user-level tool state use dobby's shared mounted home. There is no second credential store to maintain.

## Initial setup and use

1. Deploy dobby, open `https://dobby-terminal.smelt-gray.ts.net`, and authenticate Claude, Codex, CommandCode and gh as described in the main guide.
2. Review the bundled Firstmate instructions. Run its upstream one-time hook setup in the dedicated dobby home:

```sh
dobby-firstmate setup
```

3. Launch the default Claude supervisor:

```sh
dobby-firstmate
```

- Alternatively, `dobby-firstmate codex` selects the supported Codex primary. The launcher sets `FM_HOME=/workspace/firstmate` and `FM_BACKEND=tmux`, changes to that directory and starts the native CLI.
- Claude is the initial recommended lead. Firstmate can dispatch Codex and CommandCode workers; CommandCode is documented for worker/scout tasks on tmux, not as a primary supervisor.
- The launcher does not supply permission-bypass flags or start a paid agent session at container boot. Choose the desired agent permissions in the native session.
4. Register a disposable project through Firstmate's intake in `direct-PR` mode. Require human PR review; do not enable `+yolo` merge autonomy as part of this setup.
5. Start with one lead and one worker, and one build/test process at a time. This is an operating rule, not an enforced scheduler. Every worker shares the workspace's CPU/memory limits and credential authority.
6. Confirm the worker's separate worktree, actual completion wake, resulting PR and tests. Firstmate workers are tmux windows, not automatically separate Happier cards.
7. Let the project's agent register its localhost preview with `dobby-preview add "Project name" PORT --directory /workspace/project --command 'npm run dev -- --host 127.0.0.1 --port PORT'`, using the project's actual command. Supervisor starts, restarts and restores the preview service. Firstmate uses the same preview portal and mounted files as standalone agents.

## Acceptance and recovery

- Disconnect the browser and laptop during a disposable task, then confirm the native supervisor and worker continued on dobby and the supervisor noticed completion without a manual prompt.
- Check a worker failure and a pending human decision, not just the successful path.
- Restart an idle disposable workspace and verify persistent files, logins and Firstmate state. Running tmux processes stop during container replacement; start Firstmate again to reconcile saved records. Automatic crash continuation is not guaranteed.
- Git worktrees avoid editing collisions; they are not separate security sandboxes. Workers share dobby's user namespace and mounted secrets.
- The declared storage budget is now 16.25 GiB across dobby's volumes, including 12 GiB workspace and 3 GiB home. Worktree dependencies and caches still need monitoring because local-PV declarations are not disk quotas.
- Native terminal/tmux is the implementation path. Running this same supervisor through Happier's SDK-based chat remains an optional, unverified integration and is not required to use Firstmate.

## Upstream references

- [Firstmate configuration and toolchain](https://github.com/kunchenguid/firstmate/blob/427056c4181c41074ad24f051f79919330df0fa5/docs/configuration.md)
- [Reference tmux backend](https://github.com/kunchenguid/firstmate/blob/427056c4181c41074ad24f051f79919330df0fa5/docs/tmux-backend.md)
- [Watcher continuity](https://github.com/kunchenguid/firstmate/blob/427056c4181c41074ad24f051f79919330df0fa5/docs/watcher-continuity.md)

## Last updated

- Date: 2026-11-15 21:11 UTC
- Previous commit: [7da0766](https://github.com/adi-QTPi/ministry/commit/7da0766)

_Date and commit hash are auto-generated. Commit hash is of the commit previous to the commit which modified this README._
