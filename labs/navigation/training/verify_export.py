import json,sys
from pathlib import Path
import numpy as np
import torch
run=Path(sys.argv[1]);w=json.loads((run/'ffn-weights.json').read_text())
checkpoint=torch.load(run/'ffn.pt',map_location='cpu',weights_only=True)
rows=[json.loads(line) for line in (run/'attempts.jsonl').read_text().splitlines()]
rows=[r for r in rows if r['eligible'] and r['split']=='test'][:32]
x=np.asarray([r['ray_depth']+[r['requested_distance']/1.25] for r in rows],dtype=np.float32)
z=(x-np.asarray(w['mean']))/np.asarray(w['scale']);out=z.copy()
for i,layer in enumerate(w['layers']):
 out=out@np.asarray(layer['weight']).T+np.asarray(layer['bias'])
 if i<2:out=np.maximum(out,0)
t=(torch.from_numpy(x)-checkpoint['mean'])/checkpoint['scale']
for i,k in enumerate([0,2,4]):
 t=torch.nn.functional.linear(t,checkpoint['state_dict'][f'layers.{k}.weight'],checkpoint['state_dict'][f'layers.{k}.bias'])
 if i<2:t=torch.relu(t)
error=float(np.abs(out-t.numpy()).max());assert error<1e-4,error
report={'samples_checked':len(rows),'max_logit_error':error,'passed':True,'purpose':'Exported JSON normalization and dense layers reproduce saved PyTorch checkpoint.'}
(run/'export-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
