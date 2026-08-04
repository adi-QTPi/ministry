# Docker Services

Managed by Ansible `deploy_services` role. Each directory is a self-contained service.

## Directory Structure

```
docker_services/
  myservice/
    manifest.yaml          # required — Ansible metadata
    docker-compose.yaml    # required — Docker Compose config
    .env.j2                # optional — Jinja2 template → .env on host
    vault.yaml             # optional — inline-encrypted secrets
    ...                    # optional — any files shipped to host
```

## Adding a New Service

### 1. Create the directory

```bash
mkdir -p docker_services/myservice
```

### 2. Write `manifest.yaml`

```yaml
name: myservice
host: rubie
compose_file: docker-compose.yaml
uid: 1000
gid: 1000
vault_file: vault.yaml          # optional
secrets:                         # optional
  db_password: vault_myservice_db_pass
```

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Service name — also the destination folder: `/services/<name>` |
| `host` | Yes | Inventory hostname (bella, rubie, teddy, raj) |
| `compose_file` | Yes | Path relative to service directory |
| `uid` | No | Owner UID for files on target host |
| `gid` | No | Owner GID for files on target host |
| `vault_file` | No | Path to encrypted secrets file (relative to service dir) |
| `secrets` | No | Map of template-friendly names → vault key names |

### 3. Write `docker-compose.yaml`

Standard Docker Compose file. Copied verbatim — no templating applied.
Use `./data` for volume mounts — Ansible creates the directory on target.

### 4. (Optional) Add `.env.j2` templates

Jinja2 files are rendered to target with `.j2` extension stripped.

**Available variables:**
- `{{ _manifest.uid }}` / `{{ _manifest.gid }}` — ownership from manifest
- `{{ _manifest.name }}` / `{{ _manifest.host }}` — from manifest
- `{{ _secrets.<key> }}` — resolved secrets from vault

Example `.env.j2`:
```
PUID={{ _manifest.uid }}
PGID={{ _manifest.gid }}
DB_PASS={{ _secrets.db_password }}
```

### 5. (Optional) Add secrets

Create a `vault.yaml` with inline-encrypted Ansible vault strings:

```bash
just inline-vault name=vault_myservice_db_pass value="super-secret" location=../../docker_services/myservice/vault.yaml
```

Reference in manifest secrets:
```yaml
secrets:
  db_password: vault_myservice_db_pass
```

Then use in templates:
```
DB_PASS={{ _secrets.db_password }}
```

### 6. Deploy

Service deploys automatically via `site.yaml`:
```bash
just play
```

Or run only service deployments:
```bash
ansible-playbook playbooks/site.yaml --tags docker
```

## What Happens During Deploy

1. **Discover** — scans `docker_services/` for directories with `manifest.yaml`
2. **Teardown** — on all hosts except target: `docker compose down` + delete `/services/<name>`
3. **Deploy** — creates `/services/<name>`, copies all files (excluding `manifest.yaml` + `vault.yaml`), renders `.j2` files, runs `docker compose up`

## Notes

- Files starting with `.` are included (`.env.j2`, etc.)
- `manifest.yaml` and `vault.yaml` are **never** copied to target hosts
- Non-Jinja2 files are copied verbatim
- Service directory ownership is set to `uid`/`gid` from manifest if present
