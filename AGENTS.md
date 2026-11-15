# Repository workflow

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before making changes. It is the source of truth for contribution rules and may be updated as the project evolves.
- After cloning, start from the latest default branch and create a branch before editing: `<type>/<short-description>`, for example `feat/preview-proxy`. Do not include contributor or agent names in branch names. If a suitable task branch already exists, continue there.
- Keep changes focused on the assigned task and preserve unrelated work. Never work directly on or push directly to the default branch.
- Review the diff and run relevant checks. Commit when a feature or a sizable, coherent portion of work is complete. Use `[flag] short description`, with flags and examples defined in `CONTRIBUTING.md`.
- Maintain `.gitignore` as needed. Keep secrets, local configuration, caches, downloaded data, and generated artifacts out of commits.
- When asked to sync or push, push to the same task branch. Use `git push -u origin <branch-name>` for its first push, and verify the upstream before subsequent pushes.
- Open a focused PR for review before merging. Report checks run and any failures or skipped checks.

## GitHub pull requests

- After pushing a task branch, use GitHub CLI (`gh`) to open a PR against the default branch, or update its existing PR. Return the PR link.
- Give the PR a clear title and describe what changed, why, checks run, and any setup steps or limitations. Keep the description current as subsequent pushes change the scope.
