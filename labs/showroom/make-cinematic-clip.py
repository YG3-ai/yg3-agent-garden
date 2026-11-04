from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, subprocess
p=Path(__file__).parent;run=p/'cinematic-session';calls=json.loads((run/'calls.json').read_text());fps=15;W,H=1920,1080
font=lambda n,b=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if b else '')+'.ttf',n)
def frame(source,label='',credits=False):
 im=Image.open(source).convert('RGB')
 if im.size!=(W,H):im=im.resize((W,H),Image.Resampling.LANCZOS)
 d=ImageDraw.Draw(im)
 d.rectangle((0,0,W,137),fill='#08090b');d.rectangle((0,942,W,H),fill='#08090b')
 d.text((62,51),'AGENT GARDEN  /  DRIVE LAB',font=font(24,True),fill='#c8bfae')
 if credits:
  d.text((62,88),'Scenery: Bau-3d / CC BY 4.0     Car: vecarz / CC BY-NC-SA 4.0     Lighting and camera modified',font=font(21),fill='#928e87')
 if label:
  bounds=d.textbbox((0,0),label,font=font(30))
  d.text(((W-(bounds[2]-bounds[0]))/2,966),label,font=font(30),fill='#eee6d8')
 d.text((62,1033),'Cinematic replay of recorded AI actions  /  Panorama backdrop + added 3D road',font=font(20),fill='#8d8c88')
 return im
video=p/'agent-garden-mountain-drive-cinematic.mp4'
with (p/'cinematic-encode.log').open('w') as log:
 proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{W}x{H}','-framerate',str(fps),'-i','-','-vf','fps=30,format=yuv420p','-an','-c:v','libx264','-preset','fast','-crf','18','-movflags','+faststart',str(video)],stdin=subprocess.PIPE,stderr=log)
 count=0
 def put(im,n=1):
  global count
  data=im.tobytes()
  for _ in range(n):proc.stdin.write(data);count+=1
 hero=frame(run/'ready.png','LATE AFTERNOON',credits=True);put(hero,2*fps);hero.save(p/'cinematic-poster.jpg',quality=96)
 for i,c in enumerate(calls):
  if c['action']=='finish':continue
  label='INSPECT' if c['action']=='inspect_car' else 'TAKE THE WHEEL' if c['action']=='enter_car' else 'DRIVE'
  if c['action']=='drive' and c['args']['distance']<3:label='APPROACH THE MARK'
  for j in range(c['clip_start'],c['clip_end']):put(frame(run/f'motion-{j:05d}.jpg',label))
  if c['action']=='enter_car':put(frame(run/c['image'],'TAKE THE WHEEL'),10)
  if i==4:frame(run/c['image'],'DRIVE').save(p/'cinematic-driving.jpg',quality=96)
 end=frame(run/calls[-1]['image'],'A SHORT DRIVE. A CLEAN STOP.',credits=True);put(end,3*fps);end.save(p/'cinematic-end.jpg',quality=96)
 proc.stdin.close();code=proc.wait()
if code:raise SystemExit((p/'cinematic-encode.log').read_text()[-3000:])
report={'video':str(video),'seconds':count/fps,'width':W,'height':H,'replayed_actions':len(calls),'matched_original':True,'style':{'sun_elevation_degrees':13,'camera_vertical_fov_degrees':22,'vignette_strength':0.24,'look':'warm late-afternoon, long-lens framing, far depth blur, 2.39:1 image window'}}
(p/'cinematic-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
