# AGENTS.md — YG3 Agent Garden

Ground-truth orientation for this project. Update this file when the implemented system changes. Put forward-looking design in `VISION.md`.

## What this project is

The YG3 Agent Garden is an open spatial environment server for embodied agents and world models.

Agents enter through an MCP sensorimotor interface, receive first-person observations, act in persistent code-driven worlds, and generate reproducible experience. Training systems control episode lifecycle, reward, termination, and parallel rollout through a Gym-style adapter compatible with OpenEnv and GEM.

The Garden is also a YG3 medium. YG3 must be present in the substantive content of the worlds—the situations, systems, tools, characters, workflows, causal rules, and consequences—not merely in logos or provenance fields. The worlds should remain scientifically useful even if a researcher is indifferent to the brand.

## Current state

The repository contains a transport and isolation spike plus the engine-neutral core of its first causal vertical slice:

- official MCP TypeScript SDK over Streamable HTTP;
- deterministic stateful episodes;
- a disposable CPU raycaster producing first-person PNG observations;
- mapless movement, turning, interaction, and deterministic finish verification;
- no agent-facing coordinates, global map, scene graph, or hidden simulator state;
- image-payload and concurrent-episode benchmarks;
- a YG3 operations recovery world with connected systems, diagnosis, safe recovery, and multi-stage completion;
- versioned authoritative snapshots and isolated counterfactual forks;
- privileged transition traces with state diffs and verifier output;
- `GardenEnv` and `VectorGardenEnv` Gym-style lifecycle classes;
- an asset-free Godot 4 scene and persistent snapshot-to-RGB worker using a private loopback protocol;
- synchronized metric depth, semantic-segmentation frames, and camera calibration through the privileged `GodotTrainingEnv` boundary;
- tests for deterministic rendering, causal rules, snapshot isolation, vector lifecycle, and privileged-state isolation.

This is not yet the production 3D Garden. MCP defaults to the disposable CPU raycaster but supports an opt-in persistent Godot renderer through `GARDEN_RENDERER=godot`. Server shutdown owns worker shutdown, and one failed render is retried with a fresh worker. RGB, metric camera-space depth, semantic segmentation, and camera calibration are synchronized. Static Godot colliders now mirror visible geometry, but authoritative movement still uses the engine-neutral world rules; normals, optical flow, engine-owned physics, worker-pool supervision, and protocol-level OpenEnv/GEM integration remain target-state work.

## Product principle

**Useful experience first; YG3 authorship through world content.**

The Garden should target known bottlenecks in embodied AI and world models:

- action controllability and causal response;
- long-horizon memory and persistent state;
- cross-view and metric spatial reasoning;
- task and embodiment diversity;
- failure diagnosis and recovery;
- long-horizon planning and credit assignment;
- reliable closed-loop evaluation.

Do not optimize for undirected frame or trajectory count. Build capability coverage first, then scale volume.

## Architectural invariants

1. **Code owns truth.** The simulator maintains authoritative state and deterministic rules. A renderer never mutates world state.
2. **Agents are embodied and partially observed.** The public MCP surface must not reveal privileged coordinates, navigation meshes, global scene graphs, hidden task variables, or verifier state.
3. **Verification is privileged and deterministic where possible.** Rewards and success criteria inspect authoritative state through a separate control plane.
4. **MCP is the agent boundary.** Agents discover and invoke sensorimotor tools through MCP.
5. **Gym-style lifecycle is the training boundary.** Reset, step, reward, termination, state snapshots, and vectorized execution belong to orchestration—not the public agent tool surface.
6. **Every transition is recordable.** Preserve observation history, actions and durations, state diffs, contacts, collisions, task progress, and verifier output.
7. **Failures are data.** Retain failed, partial, recovery, and counterfactual trajectories rather than publishing successful demonstrations only.
8. **The AI box is unrelated infrastructure.** Do not route Garden simulation, benchmarking, or test traffic through YG3's single-flight content model.

## Data products

For embodied agents, publish live mapless MCP environments, tasks, trajectories, evaluation splits, and optional playbooks.

For world models, publish action-conditioned observations with synchronized privileged training labels: depth, normals, segmentation, optical flow, camera calibration, object poses and velocities, articulation state, contact events, state diffs, loop closures, multi-view captures, and counterfactual branches from identical saved states.

Privileged labels may appear in offline datasets and verifier channels. They must not leak into the acting agent's observation unless a task explicitly defines them as a sensor.

## First vertical slice

Build one small YG3 spatial-causal operational world in which an unfamiliar vision-language agent must:

1. explore a partially observed environment;
2. discover tangible controls and connected systems;
3. cause an effect that appears elsewhere or later;
4. remember state across occlusion and revisitation;
5. encounter or diagnose a recoverable failure;
6. complete a multi-stage objective verified from authoritative state.

Success is measured by held-out task completion and improvement across experience—not by visual polish alone.

## Repository documents

- `VISION.md` — product thesis and target architecture.
- `RESEARCH.md` — ranked data bottlenecks and dataset strategy.
- `RESULTS.md` — measured transport-spike results and limitations.
- `README.md` — current implementation and how to run it.

