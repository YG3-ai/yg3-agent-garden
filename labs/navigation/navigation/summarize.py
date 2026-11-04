import json, hashlib, collections
from pathlib import Path
import numpy as np
import sys
run=Path(sys.argv[1]); root=run.parent.parent
weights=json.loads((run/'policy.json').read_text())
checks=json.loads((run/'godot-inference.json').read_text())
x=np.asarray([r['x'] for r in checks]); expected=np.asarray([r['action'] for r in checks])
h=(x-np.asarray(weights['mean']))/np.asarray(weights['scale'])
for layer in weights['layers']:
    h=h@np.asarray(layer['weight']).T+np.asarray(layer['bias'])
    h=np.maximum(h,0) if layer['activation']=='relu' else np.tanh(h)
h=h/np.maximum(np.linalg.norm(h,axis=1,keepdims=True),1)
err=float(abs(h-expected).max());assert err<1e-5,err
metrics={}
for path in sorted(run.glob('evaluate-*.json')):
    report=json.loads(path.read_text()); results=report['results']
    cohorts={}
    for name,rows in [('all',results),('different_floor',[r for r in results if abs(r['start'][1]-r['goal'][1])>3]),('same_height',[r for r in results if abs(r['start'][1]-r['goal'][1])<.35])]:
        cohorts[name]={'reached':sum(r['success'] for r in rows),'episodes':len(rows)}
    metrics[path.stem]={'cohorts':cohorts,'reasons':dict(collections.Counter(r['reason'] for r in results)),'respawns':sum(r['resets'] for r in results),'wall_contact_ticks':sum(r['wall_ticks'] for r in results),'successful_mean_seconds':float(np.mean([r['seconds'] for r in results if r['success']])) if any(r['success'] for r in results) else None}
summary={'godot_export_max_error':err,'metrics':metrics}
replayfile=run/'replay-ffn-test.json'
if replayfile.exists() and (run/'evaluate-ffn-test.json').exists():
    replay=json.loads(replayfile.read_text())['results'][0]
    reference=next(r for r in json.loads((run/'evaluate-ffn-test.json').read_text())['results'] if r['id']==replay['id'])
    a=np.asarray(replay['trajectory']);b=np.asarray(reference['trajectory'])
    assert a.shape==b.shape and np.max(abs(a-b))<.001
    assert replay['success']==reference['success'] and replay['resets']==reference['resets']
    summary['rendered_replay_matches_test']={'id':replay['id'],'max_position_error':float(np.max(abs(a-b))),'success':replay['success']}
(run/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
selection=json.loads((run/'selection.json').read_text()) if (run/'selection.json').exists() else {}
training=json.loads((run/('training-dagger.json' if selection.get('selected')=='corrected' else 'training.json')).read_text())
collection=json.loads((run/'collection.json').read_text())
lines=['# Local learned-navigation experiment','',
       'A separate feed-forward network chooses movement in the lobby. Godot pathfinding supplies offline labels and an explicitly labeled teacher baseline; it is not used to choose learned-policy actions.','',
       '## Reserved test results','',
       '| Controller | Destinations reached | Different-floor destinations | Respawns |',
       '|---|---:|---:|---:|']
for name in ['goal','ffn','teacher']:
    result=metrics.get('evaluate-'+name+'-test')
    if result:
        all_=result['cohorts']['all']; stairs=result['cohorts']['different_floor']
        lines.append(f"| {name} | {all_['reached']}/{all_['episodes']} | {stairs['reached']}/{stairs['episodes']} | {result['respawns']} |")
lines+=['','Goal = direct steering toward the destination. FFN = learned sensor/goal policy. Teacher = map-based pathfinder. The teacher has privileged map access; it is a reference, not an equal-input neural baseline.','',
        '## Method','',
        f"Collected {collection['episodes']} teacher routes in {collection['wall_clock_seconds']:.1f} seconds, reaching {collection['reached']}. The first run collection file incorrectly names its controller `ffn`; its `mode=collect` branch actually executes only teacher actions. This metadata label is fixed in later runs. Raw files are retained.",
        f"The selected candidate is **{selection.get('selected','unselected')}**, chosen using closed-loop validation only. Initial/corrected validation scores: {selection.get('initial_validation_score')} / {selection.get('corrected_validation_score')} (reached, negative respawns, negative wall ticks).",
        f"Selected training used {training['train_states']:,} states and {training['validation_states']:,} validation states. Correction adds teacher labels at states visited by the first FFN on the first 100 training tasks. Repeated stuck-state duplicates are removed from fitting; raw records remain. Three seeds are fitted for each candidate and chosen on validation action error. Correction training time: {training['seconds']:.1f} seconds. This excludes collection, evaluation and Python startup.",
        'The 30,210-parameter network is 104 → 128 → 128 → 2 with ReLU hidden layers and tanh movement outputs. It sees 96 ray distances, relative destination and velocity. The action is held for 0.1 seconds using the same capsule, acceleration, gravity and stair-step controller as WASD. No joint-level control, RGB perception, language comprehension or LLM learning is involved.',
        f'Godot JSON inference agrees with an independent NumPy implementation to maximum action error {err:.3g}. The trainer separately checks the JSON layers against PyTorch.',
        '', '## Limits','',
        '300 training, 50 validation and 50 reserved test start-goal pairs use separate deterministic seeds. Episode states stay together, but positions and routes overlap in this one known lobby. This is not a held-out building or layout test. Relative destination inputs assume localization. Success means within 0.42 horizontal and 0.35 vertical units within 45 seconds; falls/resets fail the trial. Timeouts, invalid starts, contacts, trajectories and resets are in the JSON reports.',
        'The 96 rays form a synthetic ring of range sensors at three heights, not rendered depth or camera vision. The earlier collision FFN is a separate experiment and is not used as this policy. Model selection did not use the reserved test outcomes. Bulk data generation, training and evaluation make zero LLM/API calls.',
        '', '## Replay','']
testfile=run/'evaluate-ffn-test.json'
if testfile.exists():
    results=json.loads(testfile.read_text())['results']
    successes=[r for r in results if r['success']]
    preferred=[r for r in successes if abs(r['start'][1]-r['goal'][1])>3 and r['seconds']<=25]
    chosen=(preferred or successes or results)[0]
    (run/'preview-task.json').write_text(json.dumps({'id':chosen['id'],'selection':'First successful different-floor test episode within 25 seconds; fall back to first successful episode, then first episode. Illustrative selection, not an aggregate score.','result':{k:v for k,v in chosen.items() if k!='trajectory'}},indent=2))
    lines+=[f"`navigation-preview.mp4` is an illustrative replay of **{chosen['id']}**, selected after evaluation using the rule in `preview-task.json`. It is not a random success-rate sample. All 50 trials, including failures, are in `evaluate-ffn-test.json`. Replays use the actual FFN and shared physics, with no pathfinder fallback. The viewing camera follows motion independently of the sensor frame.", '', 'Run `watch-navigation.cmd` from the project directory to watch this policy live. Manual controls remain in `play.cmd`.']
(run/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
# Preserve code and asset hashes with the result. No original assets duplicated.
source_dir=run/'sources';source_dir.mkdir(exist_ok=True)
manifest={}
paths=[*root.glob('navigation/*.gd'),*root.glob('navigation/*.py'),*root.glob('*navigation*.ps1'),root/'training/bake_navigation.gd',root/'player.gd',root/'lobby_test.gd',root/'project.godot',root/'cache/lobby-navigation.tres',root/'cache/lobby-colliders.tscn',*root.glob('assets/*.glb')]
for path in paths:
    relative=path.relative_to(root).as_posix()
    manifest[relative]=hashlib.sha256(path.read_bytes()).hexdigest()
    if path.suffix in ['.gd','.py','.godot','.ps1']:
        target=source_dir/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(path.read_bytes())
(run/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
