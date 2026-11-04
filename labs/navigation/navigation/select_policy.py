"""Choose between initial and corrected policies using closed-loop validation only."""
import json, shutil, sys
from pathlib import Path
run=Path(sys.argv[1]); candidate=run/'corrected';candidate.mkdir(exist_ok=True)
for name in ['policy.json','policy.pt','evaluate-ffn-validation.json']:
    shutil.copy2(run/name,candidate/name)
def score(path):
    r=json.loads((path/'evaluate-ffn-validation.json').read_text())
    return (r['reached'],-sum(v['resets'] for v in r['results']),-sum(v['wall_ticks'] for v in r['results']))
initial=score(run/'initial'); corrected=score(candidate)
selected='corrected' if corrected>=initial else 'initial'
for name in ['policy.json','policy.pt','evaluate-ffn-validation.json']:
    shutil.copy2(run/selected/name,run/name)
report={'initial_validation_score':initial,'corrected_validation_score':corrected,'selected':selected,'rule':'Maximize reached destinations, then minimize resets, then wall-contact ticks. Validation episodes only; no test selection.'}
(run/'selection.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
