import sys,json,hashlib,shutil,datetime
from pathlib import Path
root=Path(__file__).resolve().parents[1];run=Path(sys.argv[1]).resolve();sources=run/'sources';sources.mkdir(parents=True,exist_ok=True)
manifest={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_files':{},'assets':{}}
for name in ['player.gd','lobby_test.gd','project.godot','training/collect.gd','training/train_ffn.py']:
 source=root/name;target=sources/name;target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists() and target.read_bytes()!=source.read_bytes():raise SystemExit('Refusing to replace saved source snapshot: '+name)
 shutil.copy2(source,target);manifest['source_files'][name]=hashlib.sha256(source.read_bytes()).hexdigest()
for name in ['assets/lobby.glb','assets/kana-walk.glb','cache/lobby-colliders.tscn']:
 source=root/name;manifest['assets'][name]={'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'bytes':source.stat().st_size}
(run/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Source and asset hashes saved:',run)
