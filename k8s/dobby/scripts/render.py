#!/usr/bin/env python3
"""Render deployment configuration locally. Never contacts Kubernetes."""
import argparse
import ipaddress
import json
import pathlib
import re
import shutil
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOKEN = re.compile(r"\$\{([A-Z_]+)\}")


def read_settings(path):
    settings = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep or not re.fullmatch(r"[A-Z_]+", key):
            raise ValueError(f"Invalid settings line: {line}")
        if key in settings:
            raise ValueError(f"Duplicate setting: {key}")
        settings[key] = value
    required = read_required_keys()
    if settings.keys() != required:
        raise ValueError(f"Settings keys differ: {sorted(settings.keys() ^ required)}")
    if settings["CONFIG_VERIFIED"] != "yes":
        raise ValueError("Verify cluster addresses, resources and paths; set CONFIG_VERIFIED=yes.")
    if any("CHANGE_ME" in v for v in settings.values()):
        raise ValueError("Replace all CHANGE_ME values.")
    for key in ("WORKSPACE_IMAGE", "RELAY_IMAGE", "DASHBOARD_IMAGE"):
        if not re.fullmatch(r"[a-zA-Z0-9./:_-]+@sha256:[a-f0-9]{64}", settings[key]):
            raise ValueError(f"{key} must use an immutable sha256 digest.")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]*\.ts\.net", settings["TAILNET_DNS"]):
        raise ValueError("TAILNET_DNS must be your tailnet DNS suffix, without a scheme.")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", settings["NODE_NAME"]):
        raise ValueError("NODE_NAME must be a Kubernetes hostname label value.")
    if not re.fullmatch(r"/[-a-zA-Z0-9_/]+", settings["BASE_DIR"]) or ".." in settings["BASE_DIR"]:
        raise ValueError("Use a dedicated absolute BASE_DIR without whitespace or '..'.")
    if not re.fullmatch(r"[^\s\"<>]+@[^\s\"<>]+", settings["TAILNET_USER"]):
        raise ValueError("TAILNET_USER must be your tailnet login identity.")
    if not re.fullmatch(r"\d+\.\d+\.\d+", settings["TAILSCALE_CHART_VERSION"]):
        raise ValueError("TAILSCALE_CHART_VERSION must be an exact chart version.")
    if ipaddress.ip_address(settings["DNS_SERVER"]).version != 4:
        raise ValueError("DNS_SERVER must be the IPv4 cluster DNS Service address.")
    return settings


def read_required_keys():
    return {line.partition("=")[0] for line in (ROOT / "settings.env.example").read_text().splitlines()
            if line and not line.startswith("#")}


def excluded_networks(settings):
    blocks = ["0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
              "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16",
              "198.18.0.0/15", "224.0.0.0/4", "240.0.0.0/4"]
    for key in ("NODE_CIDRS", "POD_CIDRS", "SERVICE_CIDRS", "EXTRA_BLOCKED_CIDRS"):
        values = [v.strip() for v in settings[key].split(",") if v.strip()]
        if not values and key != "EXTRA_BLOCKED_CIDRS":
            raise ValueError(f"{key} cannot be empty.")
        for value in values:
            network = ipaddress.ip_network(value, strict=True)
            if network.version != 4 or network.prefixlen == 0:
                raise ValueError("This bundle requires explicit IPv4 CIDRs; dual-stack needs a policy review.")
            if key == "NODE_CIDRS" and network.prefixlen != 32:
                raise ValueError("List each node IP as a /32 in NODE_CIDRS.")
            blocks.append(str(network))
    return [str(n) for n in ipaddress.collapse_addresses(map(ipaddress.ip_network, blocks))]


def replace(value, settings, excluded):
    if value == ["__PUBLIC_EXCEPT_CIDRS__"]:
        return excluded
    if isinstance(value, str):
        return TOKEN.sub(lambda match: settings[match[1]], value)
    if isinstance(value, list):
        return [replace(v, settings, excluded) for v in value]
    if isinstance(value, dict):
        return {k: replace(v, settings, excluded) for k, v in value.items()}
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=pathlib.Path, default=ROOT / "settings.env")
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "rendered")
    args = parser.parse_args()
    settings = read_settings(args.config)
    excluded = excluded_networks(settings)
    args.output.mkdir(parents=True, exist_ok=True)
    for source in sorted((ROOT / "manifests").glob("*.yaml")):
        documents = [replace(d, settings, excluded) for d in yaml.safe_load_all(source.read_text())]
        (args.output / source.name).write_text(yaml.safe_dump_all(documents, sort_keys=False))
    shutil.copyfile(ROOT / "tailscale/values.yaml", args.output / "tailscale-values.yaml")
    policy = (ROOT / "tailscale/policy.hujson").read_text()
    # JSON encoding avoids injecting policy syntax through an identity string.
    policy = policy.replace('"${TAILNET_USER}"', json.dumps(settings["TAILNET_USER"]))
    (args.output / "tailscale-policy.hujson").write_text(policy)
    (args.output / "deployment-context.txt").write_text(settings["DOBBY_CONTEXT"] + "\n")
    homepage = args.output / "homepage"
    homepage.mkdir(exist_ok=True)
    for source in (ROOT / "previews/homepage").glob("*.yaml"):
        shutil.copyfile(source, homepage / source.name)
    example = yaml.safe_load((ROOT / "previews/services.example.yaml").read_text())
    (args.output / "services.example.yaml").write_text(yaml.safe_dump(replace(example, settings, excluded), sort_keys=False))
    print(f"Rendered to {args.output}. Review before applying. Nothing deployed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        sys.exit(str(error))
