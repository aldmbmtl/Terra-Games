# Terra-Games

Community-driven [Terra](https://juno-fx.github.io/Orion-Documentation/) plugins for self-hosted
game servers — Valheim, Minecraft, Palworld, Factorio, and anything the community wants to add.

Every plugin is a **game server workload template**: Terra installs the workload schema, the game
appears in the Genesis UI workload table under the **Server** category, and users launch their own
instance per project through Hubble (Kuiper renders `scripts/chart/` at launch time).

This repository is a Terra plugin **Source** — add it in the Terra UI like any other source, alongside
or instead of the [official plugin catalog](https://github.com/juno-fx/Terra-Official-Plugins).

## Networking Policy

Game servers speak **TCP/UDP**, not HTTP. Every plugin exposes its game ports through a
**NodePort Service** (default) or **LoadBalancer** (MetalLB / cloud LB). **Ingress is never used** —
nginx ingress is HTTP/HTTPS only and cannot proxy raw game packets (UDP especially); game charts
omit the ingress template entirely. See [AGENTS.md](AGENTS.md) for the full rule.

## Plugin Catalog

| Plugin | Description | Ports | Docs |
|--------|-------------|-------|------|
| Minecraft Server (Java) | itzg/minecraft-server — vanilla, Paper, Forge, Fabric, Spigot or Bukkit, auto-installs on first boot | 25565 TCP (+ 25575 TCP RCON when enabled) | [README](plugins/minecraft/README.md) |
| Valheim Server | indifferentbroccoli image — SteamCMD auto-install, Steam backend (crossplay off by default), world saves on volume | 2456 UDP | [README](plugins/valheim/README.md) |
| Space Engineers Server | Devidian image — Windows dedicated server under Wine; world provisioned manually | 27016 UDP | [README](plugins/space-engineers/README.md) |
| Conan Exiles Enhanced Server | broccoli UE5 image — DepotDownloader auto-install, Steam backend, direct IP join | 7777 UDP (+ 25575 TCP RCON when enabled) | [README](plugins/conan-exiles/README.md) |

## Contributing a Plugin

1. `make new-plugin` from a devbox shell — scaffolds `plugins/<name>/` from `template/`
2. Edit `templates/metadata.yaml` (launch-time fields schema) and `scripts/chart/` (the workload chart)
3. `make package <name>`, then `make verify` + `make lint`
4. Add a README for your plugin and a row in the catalog table above
5. Open a PR

Full rules in [AGENTS.md](AGENTS.md).

## Adding as a Terra Source

1. Push this repository to GitHub
2. In the Terra UI, add a new Source pointing at this repository URL
3. Terra scans `plugins/*/terra.yaml` and loads every plugin automatically

## Development

```bash
# 1. Enter the dev environment (required for all make targets)
devbox shell

# 2. Create a new plugin
make new-plugin

# 3. Edit your plugin files

# 4. If your plugin has a scripts/ directory, package it
make package <plugin-name>

# 5. Verify nothing is stale
make verify
make lint
```

See [AGENTS.md](AGENTS.md) for the full make target table, field types, and plugin checklist.

## License

MIT — see [LICENSE](LICENSE).
