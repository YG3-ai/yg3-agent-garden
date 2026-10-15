# Spike results — 2026-10-15

Host-local measurements using the official MCP TypeScript SDK over Streamable HTTP on `127.0.0.1`. Each sample includes deterministic CPU rendering, PNG encoding, base64 serialization, HTTP transport, MCP parsing, and client result construction.

## Image transport

Fixed 256×256 observation. Private ancillary PNG padding models representative compressed frame sizes independently of the raycaster's unusually compressible output.

| Image payload | p50 | p95 |
|---:|---:|---:|
| 1.8 KiB | 6.81 ms | 12.83 ms |
| 33.9 KiB | 6.33 ms | 8.90 ms |
| 129.9 KiB | 10.45 ms | 11.31 ms |
| 513.9 KiB | 24.25 ms | 28.51 ms |

## Concurrent episodes

Each episode performed 12 state-changing actions. Every action returned a fresh native 256×256 raycast PNG (about 1.8 KiB).

| Concurrent episodes | Aggregate steps/sec | p50 step | p95 step |
|---:|---:|---:|---:|
| 1 | 125.84 | 6.32 ms | 9.78 ms |
| 2 | 167.12 | 9.57 ms | 13.98 ms |
| 4 | 162.71 | 20.70 ms | 24.37 ms |
| 8 | 180.88 | 39.45 ms | 45.55 ms |
| 16 | 196.37 | 71.13 ms | 85.64 ms |

## Decision

MCP image transport is not a blocker for the prototype. A 130 KiB frame adds only low tens of milliseconds on loopback, well below the likely vision-model inference time. Concurrency scales aggregate throughput, while per-episode latency rises as expected because the CPU renderer and PNG encoder run in one Node.js process.

Proceed to the engine-backed vertical slice, retaining these gates:

- mapless agent tools and privileged verifier state remain separate;
- one process or worker owns each mutable world instance;
- training orchestration controls reset, reward, termination, and concurrency;
- images may move to JPEG/WebP or resource references if remote base64 overhead becomes material;
- repeat the benchmark with the real engine, GPU renderer, remote transport, and representative frame encoding before claiming production throughput.

These numbers are a transport and isolation feasibility result, not an embodied-learning result. The next experiment must measure whether a vision-language agent improves on held-out spatial tasks after interacting with the garden.

## Persistent Godot worker — 2026-10-15

Godot 4.7.2 rendered 20 changing 256×256 observations through one persistent engine process. Each sample includes snapshot serialization, private loopback transport, a rendered frame, PNG encoding, base64 serialization, and Node.js decoding.

| Engine startup | Frame payload | p50 frame | p95 frame | Mean throughput |
|---:|---:|---:|---:|---:|
| 1,995.56 ms | 5.2 KiB | 20.30 ms | 34.25 ms | 40.62 frames/sec |

The persistent worker removes process startup from the observation loop. This is a single-worker, host-local RGB result using the asset-free prototype scene. It does not yet measure depth or segmentation passes, physics stepping, multiple engine workers, remote transport, or MCP end-to-end latency.

### End-to-end MCP path

The same persistent worker was then selected by the real Streamable HTTP MCP server. Twenty `turn` tool calls each updated authoritative state and returned a fresh 256×256 Godot PNG.

| Cold `enter_world` | Frame payload | p50 action | p95 action | Mean throughput |
|---:|---:|---:|---:|---:|
| 3,865.18 ms | 6.3 KiB | 34.52 ms | 53.49 ms | 25.38 actions/sec |

This confirms that the engine path survives the complete agent boundary without leaking privileged pose. Cold startup remains too expensive for per-episode processes, while steady-state latency is viable relative to vision-model inference. The next scaling test should supervise multiple persistent workers rather than spawning an engine for every episode.
