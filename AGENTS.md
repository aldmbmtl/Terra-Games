# AGENTS.md — Terra Games

Guidance for AI agents and automated tools working in this repository. Read before changing plugins or tooling.

> **Authoritative rules live upstream.** This repo is a community extension of the official plugin catalog.
> Read [Terra-Official-Plugins/AGENTS.md](https://github.com/juno-fx/Terra-Official-Plugins/blob/main/AGENTS.md)
> for the complete rule set (plugin taxonomy, field types, workload template contract, Kuiper annotations).
> This file documents what is specific to Terra-Games and summarizes the rules that matter most.

---

## Repository Purpose

This repository is a **Terra plugin Source** — a Git repo added via the Terra UI. Terra scans
`plugins/*/terra.yaml` and loads every plugin. All plugins live in `plugins/<plugin-name>/`.
Do not create plugins outside this directory.

Plugins here are **self-hosted game server workload templates** (Valheim, Minecraft, Palworld,
Factorio, …). One plugin per game. Terra installs the workload schema; the game appears in the
Genesis UI workload table under the **Server** category; users launch their own instance per
project through Hubble (Kuiper renders `scripts/chart/` at launch time).

## Naming Convention

- Plain lowercase DNS-1035 names: `valheim`, `palworld`, `factorio` (alphanumerics + hyphens, no dots)
- **Check the [official catalog](https://github.com/juno-fx/Terra-Official-Plugins/tree/main/plugins) first** —
  it already ships `minecraft`. Do not duplicate an official `resource_id`; pick a distinct name
  (e.g. `minecraft-bedrock`) or drop the plugin if the official one covers it.
- **Exception (decision record)**: this repo's `minecraft` plugin deliberately reuses the official
  `minecraft` resource_id — user decision, it overrides the official catalog plugin. Do not "fix"
  this collision.
- Never create a game that collides with an existing plugin in this repo.

## README Catalog Convention

- Every plugin MUST have a `README.md`
- The root `README.md` MUST list every plugin in its Plugin Catalog table (Plugin, Description, Ports,
  Docs link)
- Adding or renaming a plugin REQUIRES updating the root README table in the same change

## Plugin Type

| Type | Marker | Install target |
|------|--------|----------------|
| Game server workload template | `cluster-level` tag + `templates/metadata.yaml` with `kuiper.juno-innovations.com/chart` label + `scripts/chart/` | `argocd` namespace; launched via Genesis/Hubble (`juno-innovations.com/workload: "Server"`) |

No namespaced plugins, no cluster operators. If a future plugin needs a different scope,
add it deliberately and document the exception here.

## Critical Rules

1. **THE NETWORKING RULE — game traffic is TCP/UDP, NOT HTTP.**
   - Every game server exposes its game port(s) through a **Service of type `NodePort` (default) or
     `LoadBalancer`** (MetalLB / cloud LB) rendered in `scripts/chart/templates/service.yaml`.
   - **NO ingress. Never. In any game chart.** nginx ingress is HTTP/HTTPS only — it cannot proxy
     raw game packets (UDP especially). Game charts omit the ingress template entirely — no game
     in this catalog ships an HTTP dashboard. A plugin that routes its game port through an
     ingress is wrong.
   - UDP note: k8s Services carry UDP fine (`protocol: UDP` per port). NodePort exposes UDP on the
     same node-port range. Set `externalTrafficPolicy: Local` in the Service when the game needs
     client source-IP preservation (server list pings, auth handshakes).
   - Multi-port games: list every port in the Service (e.g. Valheim 2456/2457/2458 UDP, Minecraft
     25565 TCP + 25575 TCP RCON). Never expose a port the game does not listen on (gate RCON on
     `rcon_enabled`).
2. **Repackage after changing `scripts/`** — `make package <plugin>` regenerates
   `templates/packaged-scripts.yaml` + `templates/packaged-scripts-cleanup.yaml`. Skipping it deploys
   stale scripts with no error. `make verify` detects staleness.
3. **1MiB ConfigMap limit** — `make check-size <plugin>` warns at 900KB, errors at 1MiB. Never add
   large binaries/media to `scripts/`.
4. **Never edit generated files** — `packaged-scripts*.yaml` are always overwritten by `make package`.
5. **`metadata.yaml` is the launch-time field contract** — field names under `data.fields:` must
   exactly match keys in `scripts/chart/values.yaml`, and field defaults MUST mirror the chart
   defaults (**dual-defaults parity**: Kuiper's metadata defaults override chart values at launch).
   Rendering fails or behavior silently changes when they drift.
6. **`terra.yaml` fields are install-time only** — empty for workload templates; the Genesis UI
   is driven by the `metadata.yaml` fields schema.

## Persistence Rule

- Game worlds/saves are precious — a lost world is a lost community. Every game chart renders its
  own PVC (`pvc.yaml`: `<name>-data`, RWO) driven by launch fields: `storage_class`
  (type `k8sStorageClass`, REQUIRED) + `storage_size` (int, Gi).
- Mount it at the game's data path with per-game subPaths (e.g. Valheim `worlds_subpath` →
  `/valheim-saves`; Space Engineers four `/appdata/space-engineers/*` subPaths).
- Never store world data in the container layer or `emptyDir` (lost on restart).

## Field Types

| Type | Where | Extra keys |
|------|-------|------------|
| `string`, `int`, `boolean` | metadata.yaml | `default` |
| `select`, `multi` | metadata.yaml | `options: [...]` |
| `k8sPriority`, `k8sStorageClass`, `k8sIngressClass`, `k8sServiceAccount`, `dataVolume` | metadata.yaml | — |
| `sensitive` | metadata.yaml | mark passwords/tokens — render via Secret + `secretKeyRef`, never plain env |

## Make Targets

| Target | Usage |
|--------|-------|
| `make new-plugin` | scaffold a new game workload template from `template/` (auto-packages scripts) |
| `make package <name>` | package `scripts/` (incl. `scripts/chart/`) into a ConfigMap (required after script changes) |
| `make verify` | stale-package check |
| `make check-size <name>` | 1MiB limit check |
| `make lint` | `helm lint --strict` all charts (root + `scripts/chart/` per plugin) |

## Development Environment

`devbox shell` is a prerequisite for all make targets (helm, gnumake).
Run `make new-plugin` from inside the shell.

## Known Quirks

- **Numeric field values arrive as typed YAML**: user-entered numbers from the Genesis UI land as
  floats/ints, not strings. Kubernetes rejects non-string container args/envs, so anything
  rendered from a user field MUST use `| quote` or `"{{ }}"` string interpolation. Chart defaults
  in `values.yaml` are quoted strings and mask this.
- **`entrypoint.sh` is NOT executed for workload templates** — Kuiper renders `scripts/chart/`
  instead; the script exists only for packaging compatibility. Do not put runtime logic in it.
- **`helm lint` requires a chart version** — bump root `Chart.yaml` `version` when you change the
  plugin (templates/metadata.yaml, packaging), and `scripts/chart/Chart.yaml` when you change the
  workload chart, so users' ArgoCD syncs actually update.
- **UDP-only games can never pass a `tcpSocket` probe** (UDP has no connection handshake) — use
  an exec probe (e.g. `pgrep -f <server-binary>`) or omit liveness entirely (Space Engineers).
- **Graceful shutdown matters** — world saves happen on SIGTERM. Set
  `terminationGracePeriodSeconds` per game (Minecraft/SE 60s, Valheim 30s); never shorten below
  the game's save window.
- **Ingress never hosts game ports** — if a future game ships an HTTP dashboard AND game traffic,
  the dashboard would get its own ingress; the game ports still go through the
  NodePort/LoadBalancer Service. Two different mechanisms, never mixed in one resource.

## Adding a New Game Plugin — Checklist

1. Check the official catalog for collisions; verify the game image exists and its license permits
   self-hosting (flag non-free images in the README)
2. `make new-plugin` — prompts for the name, copies `template/`, packages scripts
3. Edit `terra.yaml` — `resource_id`, `name`, `icon`, `description`, `category: Games`, game tags
   + `cluster-level`
4. Edit `templates/metadata.yaml` — description, `fields:` schema (common set: icon/registry/repo/
   tag/cpu/memory/cpuLimit/memoryLimit/gpu/publicAccess/storage_class/storage_size + game-specific
   fields), `env_hints`
5. Edit `scripts/chart/values.yaml` + chart templates — image, `gamePort`/`gameProtocol`,
   `extraPorts`, env (all `| quote`), probes (UDP-safe), PVC mounts + subPaths, grace period;
   **keep dual-defaults parity** (metadata default == chart value)
6. Sensitive fields → `secret.yaml` + `secretKeyRef`, gated on non-empty
7. `make package <name>` — required if `scripts/` changed; `make check-size <name>` verifies the limit
8. Add plugin README.md — image, ports table, launch-field table, storage requirements, known issues
9. Add the plugin row to the root README catalog table
10. `make verify` — confirm nothing is stale; `make lint` — confirm charts pass
11. Commit `scripts/` changes AND regenerated `packaged-scripts*.yaml` together
