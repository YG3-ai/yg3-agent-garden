# YG3 Agent Garden

An open YG3 spatial environment server with an MCP sensorimotor interface and a Gym-compatible training boundary for embodied agents and world models.

The current implementation is the transport and isolation spike described below. Read [`VISION.md`](VISION.md) for the product thesis and target architecture, [`RESEARCH.md`](RESEARCH.md) for the data opportunity, and [`AGENTS.md`](AGENTS.md) for implementation invariants.

## Current implementation

This isolated spike tests the risky boundary before YG3 commits to a 3D engine:

1. Can an MCP tool return first-person image observations at usable latency?
2. Can multiple stateful episodes run concurrently without leaking state?
3. Can the agent-facing surface remain mapless while a deterministic verifier retains privileged state?

It deliberately uses a tiny deterministic CPU raycaster instead of Godot. The renderer is disposable; the episode, observation, action, and verification boundaries are the artifact under test.

## Run

```sh
npm install
npm test
npm run benchmark
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

## What this does not prove

- GPU rendering throughput
- Godot process startup and reset cost
- network latency outside loopback
- model inference latency
- whether a vision-language agent can solve the task
- GEM/OpenEnv vector-runner integration

Those are the next layer after the transport and isolation contract survives this spike.
