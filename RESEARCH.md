# Agent Garden data opportunity

Research snapshot: 2026-10-15

## Conclusion

The garden should not optimize for raw frame count. Its most defensible contribution is a large, open corpus of **diverse, action-conditioned, state-grounded spatial experience** for both embodied policies and world models.

The highest-value record is not an isolated image or a successful demonstration. It is a reproducible branch of experience:

```text
initial world state
  + embodied observation history
  + action and action duration
  + next observation
  + exact state transition
  + contacts/collisions
  + task progress
  + success/failure/recovery label
  + counterfactual branches from the same state
```

## Ranked bottlenecks

### 1. Action controllability and causal response

World models can produce visually convincing video without reliably predicting the consequences of an agent's action. World-In-World reports that visual quality does not guarantee closed-loop task success, that controllability matters more, and that post-training on action-observation data is more effective than merely upgrading the pretrained video generator.

Garden response: record every action with duration, pre/post authoritative state, visual outcome, collision/contact events, and deterministic replay. From selected states, fork several plausible actions to create counterfactual transition bundles.

Source: [World-In-World, ICLR 2026](https://proceedings.iclr.cc/paper_files/paper/2026/hash/5b4263be85820683d78675cc18d2efc7-Abstract-Conference.html)

### 2. Long-horizon memory and state persistence

Models often lose objects, alter layouts, or hallucinate structural changes after occlusion and viewpoint revisitation. Long-horizon interactive generation compounds small prediction errors.

Garden response: build tasks that require leaving a place and returning, tracking objects while they are off-screen, remembering earlier changes, and observing delayed consequences. Release loop-closure pairs and exact persistent state alongside RGB trajectories.

Sources: [LIVE](https://arxiv.org/abs/2602.03747), [MBench](https://arxiv.org/abs/2606.00793), [SCOPE, ACL 2026](https://aclanthology.org/2026.acl-long.1514/)

### 3. Cross-view and metric spatial reasoning

Current models struggle to maintain spatial relations across perspectives, reason about clearance and turning radius, and integrate geometry over multiple views. CapNav reports sharp degradation under mobility constraints and failures on insufficient spatial clearance. SITE reports especially weak spatial orientation performance and a strong correlation between spatial-intelligence scores and robot manipulation performance.

Garden response: synchronize egocentric, allocentric, depth, normals, and segmentation views during collection while exposing only permitted egocentric RGB to the acting agent. Vary camera height, field of view, footprint, turning radius, and reach.

Sources: [CapNav, CVPR 2026](https://openaccess.thecvf.com/content/CVPR2026/html/Su_CapNav_Benchmarking_Vision_Language_Models_on_Capability-conditioned_Indoor_Navigation_CVPR_2026_paper.html), [SITE, ICCV 2025](https://openaccess.thecvf.com/content/ICCV2025/papers/Wang_SITE_towards_Spatial_Intelligence_Thorough_Evaluation_ICCV_2025_paper.pdf), [SCOPE, ACL 2026](https://aclanthology.org/2026.acl-long.1514/)

### 4. Task diversity and long-tail coverage

Repeated demonstrations of a small task set have weaker transfer value than genuinely different tasks. Robotic-manipulation scaling experiments find task diversity more valuable than per-task demonstration quantity.

Garden response: parameterize causal structure, goals, layouts, object affordances, failure modes, and embodiment constraints—not merely textures and object placement. Track coverage across reasoning mode, task horizon, interaction type, and required recovery behavior.

Source: [Is Diversity All You Need for Scalable Robotic Manipulation?](https://arxiv.org/abs/2507.06219)

### 5. Failure diagnosis and recovery

Most demonstration datasets overrepresent successful expert behavior. Agents remain weak at identifying what failed, gathering new evidence, reversing a bad action, and recovering. ViFailback specifically identifies failure diagnosis and learning from failures as limitations of current VLA models.

Garden response: preserve failed runs, near misses, blocked actions, false hypotheses, and recovery continuations. Generate paired trajectories in which the same mistake is abandoned, corrected, or compounded.

Source: [ViFailback, CVPR 2026](https://openaccess.thecvf.com/content/CVPR2026/html/Zeng_Diagnose_Correct_and_Learn_from_Manipulation_Failures_via_Visual_Symbols_CVPR_2026_paper.html)

### 6. Long-horizon planning and credit assignment

Long tasks multiply opportunities for error and make it difficult to identify which earlier decisions caused eventual success or failure. Existing long-horizon navigation work is already moving toward episodes averaging roughly 150 task steps rather than short waypoint following.

Garden response: create multi-stage tasks with intermediate causal milestones, delayed effects, reversible and irreversible choices, sparse terminal goals, and privileged milestone annotations for training-time credit assignment.

Sources: [LHPR-VLN, CVPR 2025](https://openaccess.thecvf.com/content/CVPR2025/html/Song_Towards_Long-Horizon_Vision-Language_Navigation_Platform_Benchmark_and_Method_CVPR_2025_paper.html), [Horizon-length study, ICML 2026](https://openreview.net/forum?id=PnHfrCMKtp)

### 7. Reliable closed-loop evaluation

Open-loop visual scores do not establish that a world model helps an agent complete tasks. A useful dataset needs executable ground truth and outcome verification.

Garden response: keep the code world authoritative; evaluate from exact state predicates; publish held-out seeds, layouts, and task families; and score task success, intervention fidelity, memory consistency, recovery, and efficiency separately.

Sources: [World-In-World](https://proceedings.iclr.cc/paper_files/paper/2026/hash/5b4263be85820683d78675cc18d2efc7-Abstract-Conference.html), [Agent World Model](https://proceedings.mlr.press/v306/wang26jh.html)

## Two products from one garden

### For embodied agents

- MCP access to mapless first-person observations and sensorimotor actions
- interactive practice with persistent consequences
- tasks, rewards, failures, recovery, and optional inherited playbooks
- held-out evaluation across layouts, tasks, appearances, and embodiments

### For world models

- action-conditioned RGB/video trajectories
- synchronized depth, normals, segmentation, optical flow, and camera calibration
- exact object poses, velocities, articulation state, contact events, and state diffs
- revisitation and off-screen persistence sequences
- multi-view synchronized trajectories
- paired counterfactual rollouts from identical starting states
- closed-loop planning evaluation through the same action API

The acting agent must not receive privileged labels. They exist in the offline training record and verifier channel.

## Recommended first data wedge

Build **spatial-causal operational tasks**, not generic point navigation.

The first YG3 world should require an agent to:

1. explore a partially observed operational space;
2. discover tangible controls and connected systems;
3. manipulate components whose consequences appear elsewhere or later;
4. remember state across occlusion and revisitation;
5. diagnose at least one failure and recover;
6. complete a multi-stage objective verified from authoritative state.

This makes YG3's actual subject matter—the design and repair of working systems—the source of useful embodied data. It also targets several under-supplied capabilities at once without becoming another household-object navigation clone.

## Generation strategy

Start with coverage, then scale volume:

1. Define a capability matrix: viewpoint consistency, metric clearance, object permanence, causal control, tool use, delayed effects, recovery, collaboration, and horizon length.
2. Generate worlds and tasks to fill empty cells in that matrix.
3. Run multiple policies, including weak and exploratory policies, to avoid an expert-only dataset.
4. Fork high-information states into counterfactual action branches.
5. Retain failures and recoveries rather than filtering them out.
6. Hold out whole causal templates and layout families, not only random seeds.
7. Publish both the live MCP environment and versioned offline trajectory shards.

Raw quantity becomes useful only after this coverage discipline is in place.
