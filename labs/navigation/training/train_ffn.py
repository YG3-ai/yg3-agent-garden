"""Local supervised movement-prediction experiment. No LLM or network calls."""
import argparse, csv, hashlib, json, math, os, time
from pathlib import Path
os.environ.setdefault('OMP_NUM_THREADS', '4')
import numpy as np
import torch
from torch import nn

parser=argparse.ArgumentParser()
parser.add_argument('run',type=Path)
parser.add_argument('--epochs',type=int,default=120)
parser.add_argument('--seeds',type=int,nargs='+',default=[7,19,31])
parser.add_argument('--device',default='auto')
args=parser.parse_args();run=args.run.resolve();started=time.time()
torch.set_num_threads(4)
device='cuda' if args.device=='auto' and torch.cuda.is_available() else 'cpu' if args.device=='auto' else args.device
rows=[json.loads(line) for line in (run/'attempts.jsonl').read_text().splitlines() if line.strip()]
valid=[r for r in rows if r['eligible']]
if not valid:raise SystemExit('No eligible examples')
manifest=json.loads((run/'collection.json').read_text())
assert manifest['success']
X=np.asarray([r['ray_depth']+[r['requested_distance']/1.25] for r in valid],dtype=np.float32)
y=np.asarray([r['collision'] for r in valid],dtype=np.float32)
fraction=np.asarray([r['distance_fraction'] for r in valid],dtype=np.float32)
requested=np.asarray([r['requested_distance'] for r in valid],dtype=np.float32)
actual=np.asarray([r['actual_distance'] for r in valid],dtype=np.float32)
stairs=np.asarray([r['step_assists']>0 for r in valid])
indices={s:np.asarray([i for i,r in enumerate(valid) if r['split']==s]) for s in ['train','validation','test']}
groups={s:{valid[i]['region'] for i in idx} for s,idx in indices.items()}
assert not (groups['train']&groups['validation'] or groups['train']&groups['test'] or groups['validation']&groups['test'])
assert X.shape[1]==193 and np.isfinite(X).all()
for s,idx in indices.items():
 assert len(idx)>0 and len(np.unique(y[idx]))==2,(s,'needs both classes')
 assert not any(valid[i]['reset_count'] for i in idx)
mean=X[indices['train']].mean(0);scale=np.maximum(X[indices['train']].std(0),0.05)
Z=(X-mean)/scale

def auc(labels,scores):
 npos=int(labels.sum());nneg=len(labels)-npos
 if not npos or not nneg:return None
 order=np.argsort(scores,kind='mergesort');sorted_scores=scores[order]
 ranks=np.zeros(len(labels),float)
 a=0
 while a<len(labels):
  b=a+1
  while b<len(labels) and sorted_scores[b]==sorted_scores[a]:b+=1
  ranks[order[a:b]]=(a+b-1)/2+1;a=b
 return float((ranks[labels>0.5].sum()-npos*(npos+1)/2)/(npos*nneg))
def classification(labels,scores,threshold):
 pred=scores>=threshold;truth=labels>0.5
 tp=int((pred&truth).sum());tn=int((~pred&~truth).sum());fp=int((pred&~truth).sum());fn=int((~pred&truth).sum())
 precision=tp/max(1,tp+fp);recall=tp/max(1,tp+fn);specificity=tn/max(1,tn+fp)
 return {'accuracy':(tp+tn)/len(labels),'balanced_accuracy':(recall+specificity)/2,'precision':precision,'recall':recall,'specificity':specificity,'f1':2*precision*recall/max(1e-12,precision+recall),'auroc':auc(labels,scores),'tp':tp,'tn':tn,'fp':fp,'fn':fn}
def threshold_for(labels,scores):
 thresholds=np.unique(np.concatenate(([0.0,0.5,1.000001],np.linspace(0.01,0.99,99))))
 best=max(thresholds,key=lambda t:(classification(labels,scores,t)['balanced_accuracy'],classification(labels,scores,t)['f1'],-abs(t-.5)))
 return float(best)
def evaluate(scores,pred_fraction,split,threshold):
 idx=indices[split];pred_distance=np.clip(pred_fraction[idx],0,1)*requested[idx]
 error=np.abs(pred_distance-actual[idx]);m=classification(y[idx],scores[idx],threshold)
 m.update({'samples':len(idx),'collision_rate':float(y[idx].mean()),'distance_mae':float(error.mean()),'distance_rmse':float(np.sqrt(np.mean(error**2))), 'collision_distance_mae':float(error[y[idx]>.5].mean()) if (y[idx]>.5).any() else None,'clear_distance_mae':float(error[y[idx]<.5].mean()) if (y[idx]<.5).any() else None,'stairs_distance_mae':float(error[stairs[idx]].mean()) if stairs[idx].any() else None,'stairs_samples':int(stairs[idx].sum()),'threshold':float(threshold)})
 return m

results={};predictions={}
# Baselines are selected only with training/validation, never test results.
scores=np.full(len(y),float(y[indices['train']].mean()));pred=np.ones(len(y))
results['always_clear_full_distance']={'validation':evaluate(scores,pred,'validation',.5),'test':evaluate(scores,pred,'test',.5)}
predictions['always_clear_full_distance']=(scores,pred,.5)
angles=np.linspace(-50,50,16);elevations=np.linspace(25,-75,12)
sectors=[r*16+c for r,e in enumerate(elevations) for c,a in enumerate(angles) if abs(a)<=12 and -15<=e<=25]
cosines=np.asarray([math.cos(math.radians(angles[k%16]))*math.cos(math.radians(elevations[k//16])) for k in sectors])
clearance=(X[:,sectors]*6*cosines).min(1)
best=None
for margin in [0.0,.10,.20,.24,.30,.40,.50]:
 scores=1/(1+np.exp(np.clip((clearance-requested-margin)*5,-60,60)))
 pred=np.clip((clearance-margin)/requested,0,1)
 metrics=evaluate(scores,pred,'validation',.5)
 key=(metrics['balanced_accuracy'],-metrics['distance_mae'])
 if best is None or key>best[0]:best=(key,scores,pred,margin)
_,scores,pred,margin=best
results['depth_rule']={'margin_selected_on_validation':margin,'validation':evaluate(scores,pred,'validation',.5),'test':evaluate(scores,pred,'test',.5)}
predictions['depth_rule']=(scores,pred,.5)
A=np.column_stack([Z,np.ones(len(Z))]).astype(np.float64);targets=np.column_stack([y,fraction]);tr=indices['train'];va=indices['validation']
best=None
for penalty in [0.01,.1,1.0,10.0,100.0]:
 ridge=np.eye(A.shape[1])*penalty;ridge[-1,-1]=0
 coef=np.linalg.solve(A[tr].T@A[tr]+ridge,A[tr].T@targets[tr]);out=A@coef
 scores=np.clip(out[:,0],0,1);pred=np.clip(out[:,1],0,1);threshold=threshold_for(y[va],scores[va]);m=evaluate(scores,pred,'validation',threshold)
 key=(m['balanced_accuracy'],-m['distance_mae'])
 if best is None or key>best[0]:best=(key,scores,pred,threshold,penalty)
_,scores,pred,threshold,penalty=best
results['linear_ridge']={'penalty_selected_on_validation':penalty,'validation':evaluate(scores,pred,'validation',threshold),'test':evaluate(scores,pred,'test',threshold)}
predictions['linear_ridge']=(scores,pred,threshold)

class FFN(nn.Module):
 def __init__(self):
  super().__init__();self.layers=nn.Sequential(nn.Linear(193,128),nn.ReLU(),nn.Linear(128,64),nn.ReLU(),nn.Linear(64,2))
 def forward(self,x):return self.layers(x)

xt=torch.from_numpy(Z).to(device);yt=torch.from_numpy(y).to(device);ft=torch.from_numpy(fraction).to(device)
train_idx=torch.as_tensor(tr,device=device);val_idx=torch.as_tensor(va,device=device)
weight=float((len(tr)-y[tr].sum())/max(1,y[tr].sum()))
bce=nn.BCEWithLogitsLoss(pos_weight=torch.tensor(weight,device=device));regression=nn.SmoothL1Loss(beta=.1)
def loss_for(output,idx):return bce(output[:,0],yt[idx])+2*regression(output[:,1].sigmoid(),ft[idx])
models=[]
for seed in args.seeds:
 torch.manual_seed(seed);np.random.seed(seed)
 if device=='cuda':torch.cuda.manual_seed_all(seed)
 model=FFN().to(device);opt=torch.optim.AdamW(model.parameters(),lr=.001,weight_decay=.0001)
 best_loss=float('inf');best_state=None;stale=0;history=[]
 for epoch in range(args.epochs):
  model.train();order=train_idx[torch.randperm(len(tr),device=device)];loss_sum=0.0
  for batch in order.split(256):
   opt.zero_grad(set_to_none=True);loss=loss_for(model(xt[batch]),batch);loss.backward();opt.step();loss_sum+=float(loss.item())*len(batch)
  model.eval()
  with torch.no_grad():val_loss=float(loss_for(model(xt[val_idx]),val_idx).item())
  history.append({'epoch':epoch+1,'train_loss':loss_sum/len(tr),'validation_loss':val_loss})
  if val_loss<best_loss-1e-5:
   best_loss=val_loss;best_state={k:v.detach().cpu().clone() for k,v in model.state_dict().items()};best_epoch=epoch+1;stale=0
  else:stale+=1
  if (epoch+1)%20==0:print(json.dumps({'seed':seed,'epoch':epoch+1,'validation_loss':val_loss}),flush=True)
  if stale>=15 and epoch>=24:break
 model.load_state_dict(best_state);model.eval()
 with torch.no_grad():output=model(xt).cpu().numpy()
 scores=1/(1+np.exp(np.clip(-output[:,0],-60,60)));pred=1/(1+np.exp(np.clip(-output[:,1],-60,60)))
 threshold=threshold_for(y[va],scores[va]);name=f'ffn_seed_{seed}'
 m={'seed':seed,'epochs_run':len(history),'best_epoch':best_epoch,'best_validation_loss':best_loss,'parameters':sum(v.numel() for v in model.parameters()),'validation':evaluate(scores,pred,'validation',threshold),'test':evaluate(scores,pred,'test',threshold)}
 results[name]=m;predictions[name]=(scores,pred,threshold)
 checkpoint={'state_dict':best_state,'mean':torch.from_numpy(mean),'scale':torch.from_numpy(scale),'threshold':threshold,'seed':seed,'architecture':[193,128,64,2],'task':'wall-contact classification and achieved forward-distance fraction'}
 torch.save(checkpoint,run/f'{name}.pt');(run/f'{name}_history.json').write_text(json.dumps(history,indent=2))
 models.append((name,m,checkpoint))
 print(json.dumps({'model':name,'test':m['test']}),flush=True)
# Pick the exported model using validation only.
chosen=max(models,key=lambda r:(r[1]['validation']['balanced_accuracy'],-r[1]['validation']['distance_mae']))
name,m,checkpoint=chosen
torch.save(checkpoint,run/'ffn.pt')
weights=[]
for index in [0,2,4]:weights.append({'weight':checkpoint['state_dict'][f'layers.{index}.weight'].tolist(),'bias':checkpoint['state_dict'][f'layers.{index}.bias'].tolist()})
(run/'ffn-weights.json').write_text(json.dumps({'architecture':[193,128,64,2],'mean':mean.tolist(),'scale':scale.tolist(),'layers':weights,'collision_threshold':checkpoint['threshold'],'selected_seed':checkpoint['seed'],'outputs':['collision_logit','distance_fraction_logit'],'input':'192 normalized ray distances, then requested free-space distance / 1.25'},separators=(',',':')))
with (run/'predictions.csv').open('w',newline='') as f:
 writer=csv.writer(f);writer.writerow(['id','region','collision','actual_distance','requested_distance','step_assists']+[v for n in predictions for v in [n+'_score',n+'_distance']])
 for i in indices['test']:
  r=valid[i];writer.writerow([r['id'],r['region'],r['collision'],r['actual_distance'],r['requested_distance'],r['step_assists']]+[v for n,(s,p,t) in predictions.items() for v in [float(s[i]),float(p[i]*requested[i])]])
summary={'collection':manifest,'eligible_samples':len(valid),'features':X.shape[1],'splits':{s:{'samples':len(idx),'regions':sorted(groups[s]),'collisions':int(y[idx].sum()),'stairs':int(stairs[idx].sum())} for s,idx in indices.items()},'models':results,'selected_model':name,'selection':'validation balanced accuracy, then validation distance MAE; test never used to choose weights, thresholds or hyperparameters','device':device,'torch_version':torch.__version__,'gpu':torch.cuda.get_device_name(0) if device=='cuda' else None,'training_seconds':time.time()-started,'llm_calls':0,'dataset_sha256':hashlib.sha256((run/'attempts.jsonl').read_bytes()).hexdigest(),'limitations':['One fixed lobby; held-out spatial cells, not unseen buildings or layouts.','A ray-distance sensor is used, not RGB perception.','Only forward walking from rest at one walk speed is modeled; no jumping, running or turn-action prediction.','Respawns, unsupported endpoints, region crossings and anomalous recovery/overshoot are retained raw but excluded from training and test.','Spatial views can overlap cell boundaries.','A weighted classifier score is not a calibrated safety probability.','This is a predictor experiment, not a trained navigation policy.']}
(run/'report.json').write_text(json.dumps(summary,indent=2)+'\n')
lines=['# Lobby FFN experiment','',f"Collected {len(valid):,} eligible examples from {manifest['attempted']:,} attempts. Training used {device.upper()} ({summary['gpu'] or 'CPU'}). Bulk collection/training made zero LLM calls.",'','## Held-out spatial test','','| Model | Balanced accuracy | Collision recall | False clear (FN) | Distance MAE, world units |','|---|---:|---:|---:|---:|']
for n,result in results.items():
 t=result['test'];lines.append(f"| {n} | {t['balanced_accuracy']:.1%} | {t['recall']:.1%} | {t['fn']} | {t['distance_mae']:.4f} |")
lines+=['',f'Exported model: **{name}**, selected using validation only.','',f"Train / validation / test: {len(tr):,} / {len(va):,} / {len(indices['test']):,}. Inputs: 192 ray distances and proposed movement distance. Network: 193 → 128 → 64 → 2.",'','## Interpretation','','This tests whether a small FFN can predict wall contact and achieved movement from local geometry in held-out regions of the same lobby. Compare against the depth rule and linear baseline before attributing value to the network. It does not establish new-building generalization, learned navigation, safe jumping, or a calibrated collision-avoidance guarantee.','','## Exclusions','',json.dumps(manifest['excluded'],indent=2),'','All excluded attempts remain in attempts.jsonl.','','## Limitations','']+['- '+s for s in summary['limitations']]
(run/'REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'run':str(run),'selected_model':name,'device':device,'training_seconds':summary['training_seconds'],'selected_test':m['test']}),flush=True)
