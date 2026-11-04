# Lobby FFN experiment

Collected 12,000 eligible examples from 14,588 attempts. Training used CUDA (NVIDIA GeForce RTX 5080). Bulk collection/training made zero LLM calls.

## Held-out spatial test

| Model | Balanced accuracy | Collision recall | False clear (FN) | Distance MAE, world units |
|---|---:|---:|---:|---:|
| always_clear_full_distance | 50.0% | 0.0% | 227 | 0.0539 |
| depth_rule | 92.9% | 91.2% | 20 | 0.0599 |
| linear_ridge | 88.6% | 95.6% | 10 | 0.0573 |
| ffn_seed_7 | 95.0% | 98.7% | 3 | 0.0350 |
| ffn_seed_19 | 94.6% | 95.6% | 10 | 0.0303 |
| ffn_seed_31 | 95.2% | 96.9% | 7 | 0.0344 |

Exported model: **ffn_seed_19**, selected using validation only.

Train / validation / test: 8,400 / 1,800 / 1,800. Inputs: 192 ray distances and proposed movement distance. Network: 193 → 128 → 64 → 2.

## Interpretation

This tests whether a small FFN can predict wall contact and achieved movement from local geometry in held-out regions of the same lobby. Compare against the depth rule and linear baseline before attributing value to the network. It does not establish new-building generalization, learned navigation, safe jumping, or a calibrated collision-avoidance guarantee.

## Exclusions

{
  "crossed_region": 13,
  "recovery_or_overshoot": 1781,
  "unsupported_or_falling": 794
}

All excluded attempts remain in attempts.jsonl.

## Limitations

- One fixed lobby; held-out spatial cells, not unseen buildings or layouts.
- A ray-distance sensor is used, not RGB perception.
- Only forward walking from rest at one walk speed is modeled; no jumping, running or turn-action prediction.
- Respawns, unsupported endpoints, region crossings and anomalous recovery/overshoot are retained raw but excluded from training and test.
- Spatial views can overlap cell boundaries.
- A weighted classifier score is not a calibrated safety probability.
- This is a predictor experiment, not a trained navigation policy.
