# Minecraft Server (Java)

Minecraft Java Edition server workload powered by
[itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) — the most popular
Minecraft server image. Auto-installs the requested version, modloader or modpack on first launch.

> **Note**: this plugin intentionally reuses the `minecraft` resource_id from the official
> Terra catalog (user decision — ours overrides it). Disable the official source in Terra if
> both are enabled and the official one wins.

**Type:** Workload Template (Server) — install the plugin in Terra, author it in Genesis,
users launch instances through Hubble.

## Image

`itzg/minecraft-server` — `registry`/`repo`/`tag` fields (defaults `docker.io` / `itzg/minecraft-server` / `latest`).

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 25565 | TCP | Game traffic (always exposed) |
| 25575 | TCP | RCON admin console (**only when `rcon_enabled` is true**) |

The RCON port is rendered into the Service only when RCON is enabled — no dead node ports.

## EULA — REQUIRED

Mojang requires accepting the [Minecraft EULA](https://aka.ms/MinecraftEULA) to run a server.
The `eula_accept` field is a **mandatory** select (default `FALSE`) — the server will refuse to
start until set to `TRUE`. This is your legal acceptance.

## Launch Fields (Genesis workload authoring)

| Field | Default | Notes |
|-------|---------|-------|
| `eula_accept` | `FALSE` | **Select TRUE to run** — legal requirement |
| `server_type` | `VANILLA` | VANILLA, PAPER, FORGE, FABRIC, SPIGOT, BUKKIT |
| `version` | `latest` | e.g. `1.21.4` — `latest` tracks newest release |
| `jvm_memory` | `2G` | JVM heap (`2G`, `4096M`, …) — keep below `memory` |
| `difficulty` | `normal` | peaceful / easy / normal / hard |
| `max_players` | `20` | |
| `rcon_enabled` | `false` | Exposes 25575/TCP + sets `ENABLE_RCON=true` |
| `rcon_password` | — | Stored in a Secret; only used when RCON is on |
| `cpu` / `memory` | `1` / `1Gi` | Pod requests |
| `cpuLimit` / `memoryLimit` | — / `4Gi` | Pod limits (empty = none) |
| `service_type` | `NodePort` | NodePort (high port on every node) or LoadBalancer (external IP — needs MetalLB/cloud LB) |
| `storage_class` | required | StorageClass for the world volume |
| `storage_size` | `10` | World volume size in Gi |

Type/modpack variants (Forge, Fabric, Paper…) are handled via `server_type` + `version`.
See the [itzg docs](https://docker-minecraft-server.readthedocs.io/) for everything the image supports.

## Storage

World, configs and mods live in `/data` on the chart-rendered PVC
(`<name>-data`, `storage_class` + `storage_size` at launch). A lost world is a lost community —
pick a storage class with backups.

## Known Issues

- First launch downloads the server jar (and modloader/modpack) — can take several minutes;
  the startup probe allows 10 minutes before declaring failure
- `jvm_memory` sets the JVM heap — it must fit inside the pod's `memory` request and
  `memoryLimit`; raise both when raising the heap
