"""Train a goal-conditioned movement policy from local Godot teacher labels. No APIs."""
import argparse, json, os, time
from pathlib import Path
os.environ.setdefault('OMP_NUM_THREADS', '4')
import numpy as np
import torch
from torch import nn

parser=argparse.ArgumentParser()
parser.add_argument('run',type=Path)
parser.add_argument('--dagger',action='store_true')
parser.add_argument('--epochs',type=int,default=180)
parser.add_argument('--rotate',action='store_true',help='Augment training states with exact 32-heading sensor-frame rotations')
args=parser.parse_args(); run=args.run; started=time.time()
# Verify the augmentation's sensor-angle convention against the world x/z rotation.
angles=np.arange(32)*2*np.pi/32
directions=np.stack([np.sin(angles),-np.cos(angles)],axis=1)
for shift in range(32):
    a=shift*2*np.pi/32;c=np.cos(a);s=np.sin(a)
    world_rotation=np.array([[c,s],[-s,c]])
    assert np.allclose(directions@world_rotation.T,directions[(np.arange(32)-shift)%32],atol=1e-12)
torch.set_num_threads(4)
device='cuda' if torch.cuda.is_available() else 'cpu'
rows=[json.loads(line) for line in (run/'demonstrations.jsonl').read_text().splitlines()]
if args.dagger:
    extra=[json.loads(line) for line in (run/'dagger.jsonl').read_text().splitlines()]
    assert all(r['split']=='train' for r in extra)
    rows+=extra
raw_count=len(rows)
# Preserve raw failed rollouts on disk, but do not overweight identical stuck states.
unique={}
for row in rows:
    key=(row['episode'],tuple(round(v,3) for v in row['x']),tuple(round(v,3) for v in row['action']))
    unique.setdefault(key,row)
rows=list(unique.values())
assert all(r['reset_count']==0 for r in rows)
train=np.array([i for i,r in enumerate(rows) if r['split']=='train'])
val=np.array([i for i,r in enumerate(rows) if r['split']=='validation'])
assert not ({rows[i]['episode'] for i in train}&{rows[i]['episode'] for i in val})
X=np.array([r['x'] for r in rows],np.float32)
Y=np.array([r['action'] for r in rows],np.float32)
assert X.shape[1]==104 and np.isfinite(X).all() and np.isfinite(Y).all()
mean=X[train].mean(0); scale=np.maximum(X[train].std(0),.05)
x=torch.tensor((X-mean)/scale,device=device); y=torch.tensor(Y,device=device)
raw=torch.tensor(X,device=device); mu=torch.tensor(mean,device=device); sigma=torch.tensor(scale,device=device)
tr=torch.tensor(train,device=device); va=torch.tensor(val,device=device)
report={'device':device,'torch':torch.__version__,'train_states':len(train),'validation_states':len(val),'dagger':args.dagger,'split':'Held-out start/goal episodes in one known lobby. Routes and positions can overlap. Test tasks unused for training/selection.','models':[]}
report['sensor_frame_rotation_augmentation']=args.rotate
report['raw_states']=raw_count
report['duplicate_stuck_states_removed']=raw_count-len(rows)
best_overall=None
for seed in [7,19,31]:
    torch.manual_seed(seed)
    model=nn.Sequential(nn.Linear(104,128),nn.ReLU(),nn.Linear(128,128),nn.ReLU(),nn.Linear(128,2),nn.Tanh()).to(device)
    opt=torch.optim.AdamW(model.parameters(),lr=.0008,weight_decay=.0001)
    best=float('inf'); state=None; best_epoch=0
    for epoch in range(args.epochs):
        model.train(); order=tr[torch.randperm(len(tr),device=device)]
        for batch in order.split(512):
            bx=x[batch]; by=y[batch]
            if args.rotate:
                values=raw[batch].clone(); by=by.clone()
                shifts=torch.randint(32,(len(batch),),device=device)
                # Sensor azimuth uses (sin(a),0,-cos(a)); increasing camera yaw
                # therefore shifts old sensor indices backwards.
                indices=(torch.arange(32,device=device)[None,:]-shifts[:,None])%32
                values[:,:96]=values[:,:96].reshape(-1,3,32).gather(2,indices[:,None,:].expand(-1,3,-1)).reshape(-1,96)
                angles=shifts*(2*np.pi/32); c=angles.cos(); s=angles.sin()
                for a,b in [(96,97),(99,100),(102,103)]:
                    old_a=values[:,a].clone(); old_b=values[:,b].clone()
                    values[:,a]=c*old_a-s*old_b; values[:,b]=s*old_a+c*old_b
                old_a=by[:,0].clone(); old_b=by[:,1].clone()
                by[:,0]=c*old_a-s*old_b; by[:,1]=s*old_a+c*old_b
                bx=(values-mu)/sigma
            opt.zero_grad(); loss=nn.functional.mse_loss(model(bx),by); loss.backward(); opt.step()
        model.eval()
        with torch.no_grad():vl=float(nn.functional.mse_loss(model(x[va]),y[va]))
        if vl<best:
            best=vl; best_epoch=epoch; state={k:v.detach().cpu().clone() for k,v in model.state_dict().items()}
        if epoch-best_epoch>30:break
    item={'seed':seed,'validation_action_mse':best,'epoch':best_epoch+1}
    report['models'].append(item);print(item,flush=True)
    if best_overall is None or best<best_overall[0]:best_overall=(best,state,item)
_,state,selected=best_overall
model.load_state_dict(state);model.cpu().eval()
layers=[]
for name,layer in model.named_children():
    if isinstance(layer,nn.Linear):
        layers.append({'weight':layer.weight.detach().tolist(),'bias':layer.bias.detach().tolist(),'activation':'tanh' if name=='4' else 'relu'})
export={'mean':mean.tolist(),'scale':scale.tolist(),'layers':layers,'selected':selected,'inputs':'96 ray distances (32 headings x 3 heights), relative goal x/z/y, goal direction x/z, horizontal distance, relative velocity x/z','outputs':'camera-relative movement x/z, held 6 physics ticks (0.1 seconds)','teacher_at_inference':False}
(run/'policy.json').write_text(json.dumps(export))
torch.save({'state_dict':state,'mean':torch.tensor(mean),'scale':torch.tensor(scale)},run/'policy.pt')
# Independent NumPy evaluation of the JSON export checks layer order, normalization and activations.
h=(X[val[:64]]-np.asarray(export['mean']))/np.asarray(export['scale'])
for layer in layers:
    h=h@np.asarray(layer['weight']).T+np.asarray(layer['bias'])
    h=np.maximum(h,0) if layer['activation']=='relu' else np.tanh(h)
with torch.no_grad():reference=model(torch.tensor((X[val[:64]]-mean)/scale)).numpy()
error=float(np.abs(h-reference).max());assert error<1e-4,error
report.update({'selected':selected,'parameters':sum(p.numel() for p in model.parameters()),'export_max_error':error,'seconds':time.time()-started})
(run/('training-dagger.json' if args.dagger else 'training.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
