# Valheim Server

Valheim dedicated server workload powered by
[indifferentbroccoli/valheim-server-docker](https://github.com/indifferentbroccoli/valheim-server-docker).
Auto-installs the server via SteamCMD on first launch.

**Type:** Workload Template (Server) — install the plugin in Terra, author it in Genesis,
users launch instances through Hubble.

## Image

`indifferentbroccoli/valheim-server-docker:latest` (`registry`/`repo`/`tag` fields).

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2456 | UDP | Game traffic (primary — `PORT` env) |
| 2457 | UDP | Game traffic (`PORT` + 1) |
| 2458 | UDP | Extra connections |

All three are always exposed through the NodePort/LoadBalancer Service. No ingress —
Valheim traffic is pure UDP.

## Launch Fields (Genesis workload authoring)

| Field | Default | Notes |
|-------|---------|-------|
| `server_name` | `valheim` | Shown in the server list |
| `server_password` | — | **Required** — stored in a Secret |
| `world_name` | `dedicated` | Creates a new world or loads an existing one |
| `public` | `true` | `false` hides the server from the browser (join by IP) |
| `cpu` / `memory` | `2` / `4Gi` | Pod requests — raise memory for large worlds |
| `cpuLimit` / `memoryLimit` | — / — | Pod limits (empty = none) |
| `service_type` | `NodePort` | NodePort (high port on every node) or LoadBalancer (external IP — needs MetalLB/cloud LB) |
| `storage_class` | required | StorageClass for the world volume |
| `storage_size` | `10` | World volume size in Gi |

Server runs as uid/gid 1000 (pod `fsGroup: 1000`) — the storage class must allow group write.

## Storage

The chart-rendered PVC (`<name>-data`) carries two subPaths:

- `valheim` → `/valheim-saves` — **world data** (precious)
- `valheim-files` → `/valheim` — server binaries (recreated on reinstall)

The `world_name` field picks the world; reusing the same name loads the existing save.

## Known Issues

- First launch runs SteamCMD (downloads the server) — up to 10 minutes; the startup
  probe allows for it (exec probe — UDP-only game, TCP probes can never succeed)
- Graceful shutdown is 30s — the world save completes on SIGTERM, don't shorten it
- BepInEx modding is supported by the image but not exposed as a field yet
  (add `BEPINEX_ENABLED` via env hints)
