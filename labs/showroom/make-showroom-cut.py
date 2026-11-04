from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageEnhance
import json,subprocess,shutil
p=Path(__file__).parent;run=p/'dramatic-session';out=p/'showroom-cut';out.mkdir(exist_ok=True);fps=15
calls=json.loads((run/'calls.json').read_text());drives=[c for c in calls if c['action']=='drive']
font=lambda n,b=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if b else '')+'.ttf',n)
inspection=p/'showroom-session'
views={c['args']['view']:c for c in json.loads((inspection/'calls.json').read_text())}
timeline=[]
for view,count,kind in [('front',18,'exterior'),('rear',18,'exterior'),('wheel',21,'exterior'),('cockpit',30,'interior'),('cabin',27,'interior'),('seats',21,'interior')]:
 for _ in range(count):timeline.append((inspection/views[view]['image'],kind))
for c in drives[:3]:
 for j in range(c['clip_start'],c['clip_end']-6):timeline.append((run/f'motion-{j:05d}.jpg','driving'))
timeline += [(run/calls[-1]['image'],'driving')]*12 + [(inspection/views['front']['image'],'end')]*45
duration=len(timeline)/fps
music=(p.parent/'home/social-edit/original-soundtrack.wav')
if music.exists():shutil.copy2(music,out/'original-music.wav')
cache={}
def source(file):
 if file not in cache:cache[file]=Image.open(file).convert('RGB')
 return cache[file]
def compose(file,kind,H):
 W=1080
 im=ImageOps.fit(source(file),(W,H),method=Image.Resampling.LANCZOS,centering=(0.5,0.5))
 if kind=='end':im=ImageEnhance.Brightness(im).enhance(0.58)
 overlay=Image.new('RGBA',(W,H),(0,0,0,0));d=ImageDraw.Draw(overlay)
 for y in range(240):d.line((0,y,W,y),fill=(5,9,12,int(145*(1-y/240)**1.4)))
 if kind=='end':
  for y in range(H-200,H):d.line((0,y,W,y),fill=(5,9,12,int(180*((y-(H-200))/200))))
  ft=font(98,True)
  for line,yy in [('AGENT',int(H*0.28)),('GARDEN',int(H*0.28)+112)]:
   bb=d.textbbox((0,0),line,font=ft);d.text(((W-(bb[2]-bb[0]))/2,yy),line,font=ft,fill='#f5f1e9')
  for line,yy in [('A virtual showroom concept',int(H*0.28)+258),('for luxury car sales.',int(H*0.28)+302)]:
   ft=font(34);bb=d.textbbox((0,0),line,font=ft);d.text(((W-(bb[2]-bb[0]))/2,yy),line,font=ft,fill='#d9ddd7')
  for i,line in enumerate(['Car: vecarz / CC BY-NC-SA 4.0','Scenery: Bau-3d / CC BY 4.0','Lighting, camera and road added.']):
   ft=font(21);bb=d.textbbox((0,0),line,font=ft);d.text(((W-(bb[2]-bb[0]))/2,H-126+i*30),line,font=ft,fill='#c9c7c0')
 else:
  ft=font(58,True);text='AGENT GARDEN';bb=d.textbbox((0,0),text,font=ft)
  d.text(((W-(bb[2]-bb[0]))/2,65),text,font=ft,fill='#f5f1e9')
  caption = 'AI looks inside.' if kind=='interior' else 'AI controls the drive.' if kind=='driving' else 'AI inspects the details.'
  ft=font(34);bb=d.textbbox((0,0),caption,font=ft)
  d.text(((W-(bb[2]-bb[0]))/2,151),caption,font=ft,fill='#e4e5de')
 return Image.alpha_composite(im.convert('RGBA'),overlay).convert('RGB')
comment='Edited montage of a separate actual AI exterior/interior inspection and the recorded AI drive on an added synthetic road; source-speed motion, pauses and some approach actions omitted. Target stop incomplete; no completion claim. Closing text describes a potential virtual-showroom use for luxury car sales, not a production dealership service or proof of sales outcomes. Car: vecarz, https://sketchfab.com/3d-models/ferrari-laferrari-wwwvecarzcom-979f7085012e4d6399f38de3f9c39012 , CC BY-NC-SA 4.0. Scenery: Bau-3d, https://sketchfab.com/3d-models/gotthard-pass-enviroment-panorama-49935c5fb305478db94e277344477d3e , CC BY 4.0. Camera, road, lighting, animation and edit added. Original synthesized music.'
for H,label in [(1350,'portrait'),(1080,'square')]:
 video=out/f'agent-garden-{label}.mp4'
 args=['ffmpeg','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'1080x{H}','-framerate',str(fps),'-i','-']
 if music.exists():args+=['-i',str(out/'original-music.wav'),'-af',f'volume=0.85,afade=t=in:st=0:d=0.3,afade=t=out:st={duration-1.1}:d=1.1','-c:a','aac','-b:a','160k']
 args+=['-t',str(duration),'-vf','fps=30,tmix=frames=3:weights=1 2 6,format=yuv420p','-c:v','libx264','-preset','fast','-crf','18','-metadata','title=AGENT GARDEN','-metadata',f'comment={comment}','-movflags','+faststart',str(video)]
 with (out/f'encode-{label}.log').open('w') as log:
  proc=subprocess.Popen(args,stdin=subprocess.PIPE,stderr=log)
  for file,kind in timeline:proc.stdin.write(compose(file,kind,H).tobytes())
  proc.stdin.close();code=proc.wait()
 if code:raise SystemExit((out/f'encode-{label}.log').read_text()[-3000:])
 for index,name in [(0,'cover'),(65,'cockpit'),(95,'cabin'),(len(timeline)//2,'drive'),(len(timeline)-1,'end')]:compose(*timeline[index],H).save(out/f'{label}-{name}.jpg',quality=95)
 print(json.dumps({'video':str(video),'seconds':duration,'width':1080,'height':H,'bytes':video.stat().st_size}),flush=True)
(out/'README.md').write_text(f'# AGENT GARDEN social cut\n\n{duration:.2f}-second portrait (1080x1350) and square (1080x1080) edits. Minimal explanatory captions (AI inspects the details; AI looks inside; AI controls the drive) and a virtual-showroom concept for luxury car sales, with source credits at the end. The earlier edits remain in social-cut/. This combines the fresh showroom-session visual inspection with the existing dramatic-session drive; it is not one uninterrupted episode. Original videos remain untouched. The montage uses actual showroom-session inspection images and dramatic-session driving frames at source speed, omits decision pauses and some slower approach actions, and retains subtle motion blur. The ending is a cut back to the opening exterior view. Static inspection images are held for editorial timing; no synthetic cabin geometry or imagery is added. It makes no target-completion claim.\n\nAudio is the original locally synthesized music from the earlier social edit, trimmed and faded. No external music samples.\n\n'+comment+'\n',encoding='utf-8')
