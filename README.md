# YG3 Agent Garden

An open YG3 spatial environment server with an MCP sensorimotor interface and a Gym-compatible training boundary for embodied agents and world models.

The current implementation includes the original transport and isolation spike, a causal YG3 operations world, a Gym-style training boundary, and an opt-in persistent Godot renderer connected through the same MCP tools. Read [`VISION.md`](VISION.md) for the product thesis and target architecture, [`RESEARCH.md`](RESEARCH.md) for the data opportunity, and [`AGENTS.md`](AGENTS.md) for implementation invariants.

## Current implementation

The repository now has two layers:

- the original MCP image-transport and episode-isolation spike;
- an engine-neutral vertical-slice contract built around a causal YG3 operations recovery world.

The world asks an agent to capture an audience signal, operate the Writing Engine, discover a remote Publishing Rail failure, diagnose it, use a separate Reliability Relay to recover safely, rebuild the package, and publish it. Blind resets are rejected and recorded as failures. System state remains persistent across navigation and revisitation.

The tiny deterministic CPU raycaster remains the default for fast tests and transport benchmarks. A persistent Godot 4 worker now renders the same authoritative snapshots for the engine-backed path. The episode, snapshot, observation, action, recording, and verification boundaries remain renderer-independent.

## Run

```sh
npm install
npm test
npm run test:godot
npm run test:godot-mcp
npm run benchmark
npm run benchmark:godot
npm run benchmark:godot-mcp
npm start
```

The MCP endpoint is `http://127.0.0.1:8787/mcp` when started directly.

## Agent-facing tools

- `enter_world`
- `observe`
- `move`
- `turn`
- `interact`
- `finish`

Every action that changes pose returns a fresh first-person PNG. No tool exposes coordinates, a global map, a scene graph, or the authoritative verifier state.

The `observe` tool has a benchmark-only `transportPaddingKiB` argument. It inserts a valid private ancillary PNG chunk so loopback measurements can model realistic compressed-image payload sizes independently of the deliberately simple raycaster's unusually compressible output.

## Training boundary

`src/control.mjs` exposes `GardenEnv` and `VectorGardenEnv` with Gym-style lifecycle methods:

- `reset({ seed, snapshot })`
- `step(action)`
- `snapshot()`
- `trajectory()`
- `close()`

The control plane can inspect deterministic verifier results, fork counterfactual episodes from an identical saved state, and retrieve privileged transition records containing action, outcome, exact state diff, and verifier output. None of that privileged state is added to the MCP observation.

`src/control-godot.mjs` adds an asynchronous `GodotTrainingEnv`. Each reset and step returns synchronized:

- first-person RGB PNG;
- semantic-segmentation PNG with a stable class legend;
- metric camera-space depth as a packed `Float32LE` buffer, with unit and range metadata;
- camera intrinsics and privileged extrinsics;
- the normal reward, termination, and verifier result.

These labels are available only through the privileged training boundary. They are never added to agent-facing MCP results.

## Godot observation adapter

`engine/godot` contains the first asset-free Godot 4 scene and `src/godot.mjs` renders an authoritative Garden snapshot through it. Camera pose and visible station state come from the same versioned snapshot used by the verifier. Set `GODOT_BIN` when Godot is not installed in a standard macOS application or Downloads location.

`GodotWorker` keeps one engine process alive and exchanges versioned JSON messages over a private loopback TCP connection. `npm run test:godot` verifies two deterministic renders in the same process. `npm run benchmark:godot` measures engine startup separately from steady-state snapshot-to-PNG latency.

Godot's `--headless` mode disables rendering, so these commands require a working display/GPU context. The worker is private engine infrastructure, not an additional agent-facing MCP surface.

The MCP server defaults to the disposable CPU renderer. Set `GARDEN_RENDERER=godot` to use one lazily started persistent worker for live observations. The server owns worker shutdown, retries once with a fresh worker after a render failure, and preserves the same mapless public observation metadata in either mode.

## What this does not prove

- multi-worker GPU rendering throughput
- engine-backed physics and collision authority
- network latency outside loopback
- model inference latency
- whether a vision-language agent can solve the task
- protocol-level GEM/OpenEnv package integration
- normals, optical flow, and other synchronized engine render passes

Those are the next layer after the world and lifecycle contract is connected to the real engine.
