# Local learned-navigation experiment

A separate feed-forward network chooses movement in the lobby. Godot pathfinding supplies offline labels and an explicitly labeled teacher baseline; it is not used to choose learned-policy actions.

## Reserved test results

| Controller | Destinations reached | Different-floor destinations | Respawns |
|---|---:|---:|---:|
| goal | 12/50 | 0/28 | 0 |
| ffn | 34/50 | 15/28 | 0 |
| teacher | 50/50 | 28/28 | 0 |

Goal = direct steering toward the destination. FFN = learned sensor/goal policy. Teacher = map-based pathfinder. The teacher has privileged map access; it is a reference, not an equal-input neural baseline.

## Method

Collected 350 teacher routes in 61.1 seconds, reaching 348. The first run collection file incorrectly names its controller `ffn`; its `mode=collect` branch actually executes only teacher actions. This metadata label is fixed in later runs. Raw files are retained.
The selected candidate is **corrected**, chosen using closed-loop validation only. Initial/corrected validation scores: [19, -3, -37445] / [26, 0, -35938] (reached, negative respawns, negative wall ticks).
Selected training used 47,303 states and 5,196 validation states. Correction adds teacher labels at states visited by the first FFN on the first 100 training tasks. Repeated stuck-state duplicates are removed from fitting; raw records remain. Three seeds are fitted for each candidate and chosen on validation action error. Correction training time: 75.2 seconds. This excludes collection, evaluation and Python startup.
The 30,210-parameter network is 104 → 128 → 128 → 2 with ReLU hidden layers and tanh movement outputs. It sees 96 ray distances, relative destination and velocity. The action is held for 0.1 seconds using the same capsule, acceleration, gravity and stair-step controller as WASD. No joint-level control, RGB perception, language comprehension or LLM learning is involved.
Godot JSON inference agrees with an independent NumPy implementation to maximum action error 2.42e-08. The trainer separately checks the JSON layers against PyTorch.

## Limits

300 training, 50 validation and 50 reserved test start-goal pairs use separate deterministic seeds. Episode states stay together, but positions and routes overlap in this one known lobby. This is not a held-out building or layout test. Relative destination inputs assume localization. Success means within 0.42 horizontal and 0.35 vertical units within 45 seconds; falls/resets fail the trial. Timeouts, invalid starts, contacts, trajectories and resets are in the JSON reports.
The 96 rays form a synthetic ring of range sensors at three heights, not rendered depth or camera vision. The earlier collision FFN is a separate experiment and is not used as this policy. Model selection did not use the reserved test outcomes. Bulk data generation, training and evaluation make zero LLM/API calls.

## Replay

[The navigation video](../../../../docs/media/navigation-learning.mp4) is an illustrative replay of **test-0005**, selected after evaluation using the rule in `preview-task.json`. It is not a random success-rate sample. All 50 trials, including failures, are in `evaluate-ffn-test.json`. Replays use the actual FFN and shared physics, with no pathfinder fallback. The viewing camera follows motion independently of the sensor frame.

Run `watch-navigation.cmd` from the project directory to watch this policy live. Manual controls remain in `play.cmd`.

## Public snapshot

Includes the selected policy, task definitions, training/selection summaries and all reserved test outcomes/trajectories. Large raw demonstrations/recovery data, the collection trajectories, per-seed historical checkpoints and source snapshots remain local. Rerun `run-navigation.cmd` to generate a fresh complete experiment. Public path/setup changes are documented in the lab README; the reported numbers are the original measured run.
