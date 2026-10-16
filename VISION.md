# YG3 Agent Garden

## Thesis

YG3 is building an open spatial environment server where embodied agents and world models acquire useful experience through interaction.

The Garden is a new YG3 content channel. A blog communicates through articles; a documentary communicates through scenes; the Garden communicates through formative experience. YG3 is not placed inside the environment as an advertisement. The environment is built from YG3's real subject matter: designing, connecting, operating, diagnosing, and improving intelligent systems.

An agent should be able to enter the Garden through MCP, perceive a first-person world, act within it, experience consequences, and leave with better spatial and causal understanding. A training system should be able to run the same worlds at scale, verify outcomes from authoritative state, and collect versioned trajectories for embodied policies and world models.

## Target architecture

```text
Embodied agent / world model
            │
            │ MCP sensorimotor tools
            ▼
YG3 Garden agent boundary
  ├── observe
  ├── look / turn / move
  ├── manipulate / use
  ├── communicate
  └── finish
            │
            ▼
Authoritative code-driven world
  ├── persistent state
  ├── physics and interaction rules
  ├── YG3 systems, services, people, and methods
  ├── tasks and causal consequences
  └── snapshots and deterministic replay
       │                         │
       │ visual conditions      │ privileged state
       ▼                         ▼
Renderer                    Verifier and recorder
       │                         │
       └──── observations ───────┴── rewards, traces, datasets

Training framework
  └── OpenEnv control plane / GEM-compatible reset-step adapter
```

## Why this is useful

Embodied AI needs more than passive images and successful demonstrations. World models need action-conditioned transitions, stable state across long horizons, exact causal outcomes, and counterfactual experience. Code worlds can provide these at a scale and level of observability that real-world recording cannot.

The Garden's distinctive training unit is a branch of experience:

```text
initial state
+ observation history
+ action and duration
+ next observation
+ exact state transition
+ contacts and collisions
+ task progress
+ success, failure, or recovery
+ alternative actions from the same saved state
```

## YG3 as world content

The first worlds should turn YG3's work into spatial-causal experience:

- systems that must be inspected, connected, and repaired;
- content and distribution pipelines represented as working processes;
- simulated clients with operational constraints and incomplete information;
- tools whose effects propagate through a persistent environment;
- agents and characters who coordinate through roles and shared systems;
- consequences that make good and bad methodology visible.

YG3 identity should remain recognizable if every logo is removed. It lives in what the world teaches, how its systems work, and which problems it makes possible to solve.

## Development stages

### Stage 0 — transport spike

Validate MCP image transport, episode isolation, deterministic reset, privileged verification, and concurrent throughput with a disposable renderer. This exists now.

### Stage 1 — engine-backed vertical slice

Replace the raycaster with one small authored 3D world. Preserve the MCP contract. Add authoritative snapshots, depth and segmentation capture, a Gym-style control plane, trajectory recording, and one held-out evaluation task family.

The engine-neutral portion now exists: the first causal world, snapshots and counterfactual forks, privileged transition recording, deterministic verification, and scalar/vector Gym-style lifecycle. An opt-in persistent Godot worker renders deterministic RGB directly from authoritative snapshots through the same MCP tools. The privileged Godot training boundary also returns synchronized metric camera-space depth, semantic segmentation, and camera calibration. Static engine colliders mirror the rendered geometry, while engine-owned movement, worker pools, motion labels, and held-out variants remain.

### Stage 2 — learning evidence

Run unfamiliar vision-language agents through repeated rounds. Compare zero-experience baselines with trajectory, playbook, or model-based learning conditions. Demonstrate improvement on held-out layouts or causal variants.

### Stage 3 — world-model data

Add synchronized multi-view capture, counterfactual branching, loop-closure sequences, embodiment variation, action-conditioned offline shards, and closed-loop planning evaluation.

### Stage 4 — Garden scale

Expand world and task diversity from a capability matrix. Automate validation before publishing new worlds. Vectorize execution only after the single-world contract and evaluation remain stable.

## Non-goals for the first slice

- constructing the full YG3 universe;
- training a new neural renderer;
- maximizing undirected trajectory count;
- exposing privileged state to make agents appear capable;
- claiming embodied-learning value before controlled evaluation;
- using YG3 branding as a substitute for useful world content.

