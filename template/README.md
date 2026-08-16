# Generic Game Server Workload Template

The starter scaffold for every plugin in this repository. `make new-plugin`
copies this directory into `plugins/<name>/` and replaces every `PLUGIN`
occurrence with the plugin name.

Every plugin here is a **workload template**: Terra installs the schema, the
game appears in the **Genesis** UI workload table (category **Server**), and
users launch their own instance per project through **Hubble** (Kuiper renders
the chart in `scripts/chart/` at launch time).

## Structure

| Path | Purpose |
|------|---------|
| `terra.yaml` | Terra app-store metadata — `cluster-level` tag, empty install-time fields |
| `Chart.yaml` | Root Helm chart (metadata ConfigMap only) |
| `templates/metadata.yaml` | `terra-metadata` ConfigMap — `kuiper.juno-innovations.com/chart` label, `juno-innovations.com/workload: "Server"`, launch-time **fields schema** + `env_hints` |
| `scripts/chart/` | **The real chart** — rendered by Kuiper at workload launch |
| `scripts/chart/values.yaml` | Kuiper contract keys + game settings (dual-defaults parity with metadata fields) |
| `scripts/chart/templates/server.yaml` | StatefulSet — game container, ports, env, probes, resources, PVC mount |
| `scripts/chart/templates/service.yaml` | **NodePort/LoadBalancer Service** — the game's exposure |
| `scripts/chart/templates/pvc.yaml` | Chart-rendered world storage (`storage_class` + `storage_size` fields) |
| `scripts/chart/templates/secret.yaml` | Optional — sensitive launch fields (`sensitive: true` in metadata) |
| `scripts/entrypoint.sh` | Packaging placeholder — **NOT executed** (Kuiper uses `scripts/chart/`) |
| `packaged-scripts-template*.yaml` | Packaging templates consumed by `make package` |
| `.helmignore` | Keeps `terra.yaml` out of the packaged Helm chart |

## Networking rules (MANDATORY)

1. Game servers listen on **TCP/UDP**. Expose them via the Service —
   users pick `service_type` at launch (select field in metadata):
   - `NodePort` (default) — high port on every node
   - `LoadBalancer` — external IP when the cluster has MetalLB
     or a cloud load balancer
2. **NO ingress, ever, in game charts.** nginx ingress is HTTP/HTTPS only —
   it cannot proxy raw game packets. Game charts omit the ingress template
   entirely (no HTTP dashboards in this catalog).

## Per-game edits

- Set `repo`, `gamePort`, `gameProtocol`, `extraPorts` in
  `scripts/chart/values.yaml`; expose anything user-tunable as a metadata
  field in `templates/metadata.yaml` (defaults MUST mirror — metadata field
  defaults override chart values at launch)
- **Probes**: template ships TCP probes — fine for TCP games. For
  **UDP-only** games a `tcpSocket` probe NEVER succeeds (UDP has no
  connection handshake) — replace with an exec probe (e.g.
  `pgrep -f <server-binary>`) or omit liveness entirely
- Set `terminationGracePeriodSeconds` per game — world saves happen on
  SIGTERM, don't let k8s kill the server mid-save
- World/save storage: the chart renders a PVC from `storage_class`
  (k8sStorageClass field, required) + `storage_size` (Gi); mount it at the
  game's data path with the right subPath layout
- **Verify the game image's architectures** (Docker Hub tag → architectures, or
  inspect the OCI manifest) — single-arch images get
  `nodeSelector: {kubernetes.io/arch: <arch>}` in `scripts/chart/values.yaml`
  (default `{}` = no pinning, e.g. multi-arch images schedule anywhere)
- Sensitive fields (passwords): mark `sensitive: true` in metadata, render
  via `secret.yaml` + `secretKeyRef` — never as plain env values
