> Public source snapshot: see [setup and included/excluded outputs](../README.md), [asset attribution and licenses](../THIRD_PARTY_ASSETS.md), and [finished videos](../../docs/media/README.md). Historical recording/session filenames below describe locally retained outputs, not files shipped in this checkout.

# Agent Garden Lobby Lab

Manual character-and-environment test before collecting FFN training data. Open `project.godot` in Godot 4.7.2 and press F6 on lobby-test.tscn (or F5 for the main scene), or double-click play.cmd. play.ps1 accepts -GodotBinary or GODOT_BIN and also detects the existing local Godot install.

## Controls

- WASD: move relative to the camera.
- Mouse: look around; left click captures the mouse.
- Shift: faster walking (uses the supplied walk animation at a higher rate).
- Space: jump.
- F: toggle first-person / third-person view.
- R: reset to the ground-floor spawn.
- Esc: release the mouse. Close the game window to exit.

The third-person camera hides the character when a nearby wall would push the camera into her body; F always offers a first-person view.

The default spawn faces down the lower hall. Turn around with the mouse toward the stair hall behind the spawn to test the two staircases. Actual visible floor, walls and stairs supply the collisions. Exits are open; R resets the player, and falling below the level also triggers a reset.

## What works

Kana imports as a skinned character with 66 bones and a 1.2667-second walk clip. Her source mesh is in centimeter-like units and is normalized to about 1.70 world units tall. Horizontal hip translation is removed from the runtime animation so the visual cannot drift away from the collision capsule. The original GLB is unchanged. Only a walk animation was supplied; stopping holds a walk pose, and faster walking changes playback speed. No separate idle, run, jump, or foot-IK animation is claimed.

The body is a CharacterBody3D capsule with gravity, wall collision, floor snapping and bounded step assistance. Step assistance checks body clearance and confirms a real walkable stair tread before raising the capsule. It does not add an invisible ramp. The same controller method, set_control(), is available for future scripted data collection or a learned policy. Grounding, collision flags and achieved motion will be available from this body.

The lobby is itself a skinned import. Raw unposed trimesh collisions did not match the rendered architecture. The manual scene therefore bakes the current visible lobby pose into 94 static collision shapes and saves cache/lobby-colliders.tscn. A graphics-enabled first launch is needed to build that cache; later headless physics tests can reuse it. Rebuild the cache after changing the lobby asset or its pose. No dynamic building animation is supported by this static cache.

The 0.34-unit maximum step is sized for this lobby's approximately 0.337-unit stair risers. Scale and controller dimensions are test settings, not verified physical measurements. Room layouts, asset scale, controller settings and sensors must be fixed/versioned or deliberately varied before collecting training labels.

## Verification

inspection/manual-smoke.json records ground settling, forward movement, animated foot motion, root-travel locking, and wall contact. inspection/stairs-smoke.json records both stair flights, the upper-floor height and the descent back to the lower floor. Step-assist counts are controller corrections, not counts of distinct physical treads. These tests run Godot directly and make no LLM/API calls.

Run `godot --headless --path . -- --smoke` or `godot --headless --path . -- --stairs-smoke` after the collision cache is built. Graphics-enabled smoke runs also save screenshots under inspection/.

## Automated FFN experiment

The first experiment is complete: [results and baselines](experiments/ffn-v1-20261104/REPORT.md). It collected 12,000 eligible movement examples from 14,588 actual Godot attempts in about 152 seconds, then trained three small FFNs on the RTX 5080. Bulk collection and training make zero LLM/API calls. The manual game still has no FFN policy controlling it.

Double-click `run-experiment.cmd` to repeat the pipeline into a new timestamped experiment directory. Or run `./run-experiment.ps1 -Samples 12000 -Seed 20261104`. The script uses the cached collision geometry, saves source/asset hashes, runs headless Godot with fixed simulation timesteps, and trains/evaluates using local Python/PyTorch. Existing data directories are protected from accidental overwriting. Node.js, Codex CLI, API keys and an LLM are not dependencies of this pipeline. Python dependencies are in training/requirements.txt; the current machine already has them installed.

`training/collect.gd` samples supported, non-overlapping starting poses and forward movement attempts using the same CharacterBody3D controller as manual play. Observations are a 16 x 12 ray-distance grid, not screenshots. Each input adds the proposed unobstructed movement distance. Labels are actual wall contact and achieved forward-distance fraction. Fixed actions last 12, 24, 36 or 48 physics ticks, starting at rest and using the same walk speed and step assistance. Visual feedback is disabled only in the headless collector; movement physics is shared.

Data is split by 2.5-unit spatial cells and floor band, with buffered start/end points and no accepted trajectory crossing a cell boundary. No spatial-cell ID occurs in multiple splits. Train/validation/test have 8,400 / 1,800 / 1,800 eligible examples. One lobby is used; nearby views and mirrored geometry can still overlap. This is not an unseen-building result.

All attempts remain in attempts.jsonl. Falling/unsupported endpoints, respawn events, region crossings and anomalous recovery/overshoot are excluded from model fitting and scored test rows, not deleted. The current run excluded 2,588 attempts. User-triggered and automatic resets are counted and given reasons so a teleport back to spawn cannot be labeled as ordinary motion. The independent reset smoke check verifies this instrumentation. Jumping and running are outside this first training task.

`training/train_ffn.py` trains a 193 → 128 → 64 → 2 MLP (33,218 parameters) with a wall-contact head and a movement-distance head. Thresholds, early stopping, baseline hyperparameters and the exported seed are selected using training/validation only. Test results do not select the model. Three random seeds are reported alongside always-clear, depth-rule and linear-ridge baselines. The collision output is a weighted classifier score, not a calibrated safety guarantee.

The selected model reached 94.6% balanced test accuracy versus the depth rule's 92.9%; it missed 10 of 227 contacts versus 20, with 102 false alarms versus 84. Mean distance error was 0.0303 versus 0.0599 world units. This is a modest classification improvement and a larger distance-prediction improvement with a false-alarm tradeoff, not an autonomous navigation result.

Each experiment retains REPORT.md, report.json, predictions.csv, collection metadata, three model checkpoints, selected ffn.pt, deployable ffn-weights.json, histories and a source snapshot. The exported normalization/dense layers are checked against the PyTorch checkpoint by training/verify_export.py. The JSON report's stairs cohort means examples with controller step assistance; individual physical treads are not semantically annotated.

That first FFN predicts outcomes. A separate goal-conditioned policy experiment now chooses movement, described below.

## Learned navigation experiment

The navigation experiment lives in `navigation/`, with the first run in `experiments/navigation-v1-20261104/`. See that run's `REPORT.md` for completed-route results and limitations. It trains a separate 104 → 128 → 128 → 2 FFN (30,210 parameters), rather than turning the earlier collision classifier into a route planner. Manual WASD play remains available through `play.cmd`.

Double-click `run-navigation.cmd` to repeat collection, initial training, 100 training-only recovery rollouts, corrected training, validation-based candidate selection and reserved test evaluation. It creates a fresh directory, uses the installed local Godot and PyTorch, and calls no LLMs or APIs. `GODOT_BIN` can override the Godot executable. The pipeline takes several minutes on this machine. Existing experiment directories are protected against overwrite by the launcher.

Godot bakes a navigation mesh from the cached **posed collision geometry**, using a conservative agent clearance. Its pathfinder supplies offline demonstration labels, recovery labels and the explicit teacher baseline. The learned policy does not receive the navigation mesh, path waypoints or teacher actions while being evaluated. It receives 96 normalized horizontal ray distances (32 headings at three body heights), the relative goal position/direction/distance and horizontal velocity. These are synthetic range sensors, not camera images. Knowing the relative destination assumes localization. Outputs are two camera-relative movement components held for six 60 Hz physics ticks. The shared player controller supplies acceleration, gravity, floor snapping and bounded stair steps; the FFN does not learn joint animation or physics.

Tasks include both floors and stairs. Train, validation and test contain 300 / 50 / 50 deterministic start-goal episodes with separate random seeds. Entire episode states stay together. Positions, routes and mirrored architecture can overlap across splits, so this measures new start-goal pairs in **one known building**, not new-space generalization. Validation selects checkpoints, random seeds and the initial versus corrected candidate. The 50 reserved test episodes are used only after that selection. The goal-only baseline walks directly toward the destination; the teacher baseline queries a map. These are different information budgets and are labeled explicitly.

All raw demonstrations and recovery records, including failed routes, remain on disk. Repeated identical stuck states are deduplicated for fitting. Correction training uses only training tasks and adds exact sensor-frame rotation augmentation. Respawns terminate a trial as a failure. Success requires coming within 0.42 horizontal and 0.35 vertical world units of the destination within 45 seconds. Full trajectories, timeouts, wall-contact ticks and reset counts are retained. JSON export is verified against PyTorch and independently against Godot inference. Source snapshots and geometry hashes accompany the results.

## Assets

Lobby by local.yany: https://sketchfab.com/3d-models/lobby-9057cb241be74393b91952143c3ffe87 . Creator: https://sketchfab.com/local.yany . Embedded license: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ . Original geometry retained; lighting, camera, static collision cache and controller added.

Free 018 Kana Walk by ddd: https://sketchfab.com/3d-models/free-018-kana-walk-f465652729944a66aed790cd88fa0b0f . Creator: https://sketchfab.com/endonoriko . Embedded license: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ . Original asset retained; runtime scale, root-travel handling and controller animation playback added.

Download both credited models separately into assets/. This public source snapshot includes selected results and weights; large raw data and derived caches are excluded. See [setup](../README.md) and [full asset attribution](../THIRD_PARTY_ASSETS.md).
