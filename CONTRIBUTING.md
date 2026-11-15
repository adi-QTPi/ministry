# Contributing

Keep changes focused, reviewable, and reproducible. These guidelines apply to every contributor, including work done with AI agents.

## Branches and pull requests

- Start from the latest default branch. Create a separate branch for each feature, fix, or task using `<type>/<short-description>`, such as `feat/preview-proxy`, `fix/ingress-routing`, or `docs/setup`. Do not include contributor or agent names in branch names.
- Open a pull request for every change. Do not push directly to the default branch.
- Keep each PR focused on one purpose. Separate unrelated refactors, formatting changes, and dependency updates.
- Use draft PRs for unfinished work. Mark them ready only after reviewing the diff and running relevant checks.
- Describe what changed, why it changed, and how it was tested. Include screenshots for UI changes and call out breaking changes or setup steps.
- Review the complete diff and resolve review comments and failing checks before merging.
- Keep your branch current with the target branch. Resolve conflicts carefully and rerun affected checks.
- Never rewrite shared branch history without coordinating with its contributors. If updating your own PR requires a force push, use `git push --force-with-lease`.
- Delete merged feature branches when they are no longer needed.

## Commit messages

Use this format for commits and squash-merge titles:

```text
[flag] short description
```

Use lowercase flags and a short, imperative description of the change:

- `feat`: add functionality.
- `fix`: correct a bug.
- `design`: change UI, styling, or visual assets.
- `docs`: update documentation.
- `refactor`: restructure code without changing behavior.
- `test`: add or update tests.
- `chore`: maintain tooling, dependencies, or repository configuration.
- `ci`: change CI workflows.
- `perf`: improve performance.
- `wip`: checkpoint unfinished work on a feature branch.

Examples:

```text
[feat] add restricted preview proxy
[fix] correct ingress routing
[design] improve dashboard spacing
[chore] ignore local cache files
```

- Keep each commit focused on one logical change. Use the body to explain reasoning when needed.
- Commit after completing a feature or a sizable, coherent portion of work. Avoid leaving all changes in one large end-of-task commit.
- Replace or squash `wip` commits before merging. The final merge title must describe the completed change.
- Avoid vague descriptions such as `update`, `changes`, or `fix stuff`.

## Pushing changes

- Push commits to the same feature branch you are working on. For the first push, use `git push -u origin <type>/<short-description>`; subsequent pushes can use `git push` after verifying the upstream points to that branch.
- Open a PR to propose merging your branch into the default branch.

## Staging and ignored files

- Check `git status` and review `git diff` before staging. Stage specific files or hunks, then review `git diff --cached` before committing.
- Update the appropriate `.gitignore` whenever your changes introduce generated files, caches, build output, logs, or local configuration. Include the ignore rule in the same PR.
- Keep ignore rules specific, grouped, and commented where their purpose is unclear. Never hide source files or required project assets with broad patterns.
- Use your global Git ignore for personal editor and operating-system files that are not shared project concerns.
- Never commit secrets, credentials, private keys, or populated `.env` files. Provide an `.env.example` with placeholders when configuration is required.
- Do not commit local environments, downloaded datasets, model weights, or large generated artifacts. Document how to obtain required data and choose appropriate external storage before adding large files.
- `.gitignore` does not stop tracking existing files. For files that should become local-only, explicitly remove them from the index with `git rm --cached <path>` and review the change. If a secret was committed, revoke or rotate it immediately and coordinate history cleanup.

## Working with AI agents

- Read applicable `AGENTS.md` files and existing project conventions before making changes. Give agents a clear task and scope.
- Review every generated change yourself. The contributor remains responsible for correctness, security, and maintainability.
- Preserve other contributors' work. Do not discard unrelated edits, reset branches, or overwrite files to make a task easier.
- Keep generated changes within scope. Avoid unsolicited rewrites, new dependencies, or sweeping formatting changes.
- Never put secrets or private data into prompts, committed logs, or generated documentation.
- Run relevant tests, linting, and build checks before requesting review. State exactly what ran and disclose anything skipped or failing.
- Update documentation and `.gitignore` alongside code when behavior, setup, or generated output changes.
- Before opening a PR, inspect the complete diff for accidental files, debug output, temporary scripts, and unrelated changes.
