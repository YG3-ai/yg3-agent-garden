"""Copy separately obtained assets into the labs; extract the embedded panorama locally."""
import argparse, json, shutil, struct
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
for name in ['apartment','car','environment','lobby','character']:p.add_argument('--'+name,type=Path)
args=p.parse_args();root=Path(__file__).resolve().parent
destinations={'apartment':'home/assets/modern-apartment.glb','car':'showroom/assets/laferrari.glb','environment':'showroom/assets/gotthard-pass.glb','lobby':'navigation/assets/lobby.glb','character':'navigation/assets/kana-walk.glb'}
for name,destination in destinations.items():
    source=getattr(args,name)
    if source is None:continue
    target=root/destination;target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists():raise SystemExit(f'Refusing to overwrite {target}')
    data=source.read_bytes()
    if data[:4]!=b'glTF':raise SystemExit(f'Not a binary glTF file: {source}')
    if name=='environment':
        length,kind=struct.unpack_from('<II',data,12)
        if kind!=0x4E4F534A:raise SystemExit('Expected a JSON GLB chunk')
        document=json.loads(data[20:20+length]);offset=20+length
        binary_length,binary_kind=struct.unpack_from('<II',data,offset)
        if binary_kind!=0x004E4942:raise SystemExit('Expected embedded binary data')
        view=document['bufferViews'][document['images'][0]['bufferView']]
        begin=offset+8+view.get('byteOffset',0)
        image=data[begin:begin+view['byteLength']]
        if not image.startswith(b'\x89PNG\r\n\x1a\n'):raise SystemExit('Expected the credited model\'s embedded PNG panorama')
        panorama=target.with_name('gotthard-panorama.png')
        if panorama.exists():raise SystemExit(f'Refusing to overwrite {panorama}')
        panorama.write_bytes(image)
    shutil.copy2(source,target);print(f'Prepared {target.relative_to(root)}')
