from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,subprocess,textwrap
p=Path(__file__).parent;run=p/'session';calls=json.loads((run/'calls.json').read_text());verdict=json.loads((run/'verdict.json').read_text())
W,H=1280,900;fps=15
font=lambda n,b=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if b else '')+'.ttf',n)
def base(source,label):
 c=Image.new('RGB',(W,H),'#101c22');c.paste(Image.open(source).convert('RGB').resize((1280,720),Image.Resampling.LANCZOS),(0,94));d=ImageDraw.Draw(c)
 d.text((30,17),'AGENT GARDEN / MOUNTAIN DRIVE LAB',font=font(30,True),fill='#f4f0e7')
 d.text((31,58),'An AI inspects the car, then tries a short drive.',font=font(21),fill='#b1c9c7')
 d.rounded_rectangle((25,118,620,165),radius=8,fill='#142c33');d.text((40,127),label,font=font(23,True),fill='#b6d8c6')
 d.text((30,830),'Actual AI controls • Panorama backdrop + added 3D road • Decision pauses removed',font=font(20),fill='#b1c9c7')
 d.text((30,864),'Scenery: Bau-3d / CC BY 4.0   |   Car: vecarz / CC BY-NC-SA 4.0   |   Camera, road and lighting added',font=font(17),fill='#8aabb0')
 return c
video=p/'agent-garden-mountain-drive.mp4';log=(p/'encode.log').open('w')
proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{W}x{H}','-framerate',str(fps),'-i','-','-vf','fps=30,format=yuv420p','-an','-c:v','libx264','-preset','fast','-crf','19','-movflags','+faststart',str(video)],stdin=subprocess.PIPE,stderr=log)
count=0
def put(im,n=1):
 global count
 b=im.tobytes()
 for _ in range(n):proc.stdin.write(b);count+=1
intro=base(run/'ready.png','TWO ASSETS. ONE SMALL EXPERIMENT.');put(intro,2*fps);intro.save(p/'preview-inspection.jpg',quality=95)
for i,call in enumerate(calls):
 a=call['action']
 if a=='inspect_car':label='INSPECT / '+call['args']['view'].upper()
 elif a=='enter_car':label='SWITCH TO THE DRIVING VIEW'
 elif a=='drive':label='DRIVE / '+('STEER RIGHT' if call['args']['steering']>0 else 'STEER LEFT' if call['args']['steering']<0 else 'FORWARD')
 elif a=='finish':continue
 else:label='LOOK AHEAD'
 for j in range(call['clip_start'],call['clip_end']):
  im=base(run/f'motion-{j:05d}.jpg',label);put(im)
 put(im,5)
 if a=='drive' and i==len(calls)//2:im.save(p/'preview-driving.jpg',quality=95)
last=calls[-1];end=base(run/last['image'],'MARKED STOP REACHED' if verdict.get('completed') else 'SHORT DRIVE RECORDED / STOP TARGET INCOMPLETE')
shade=Image.new('RGBA',end.size,(0,0,0,0));d=ImageDraw.Draw(shade);d.rectangle((40,285,1240,665),fill=(12,22,30,230));end=Image.alpha_composite(end.convert('RGBA'),shade).convert('RGB');d=ImageDraw.Draw(end)
d.text((75,320),'WHAT THE AGENT REPORTED',font=font(29,True),fill='#b6d8c6')
note=(run/'agent-note.txt').read_text();y=385
for line in textwrap.wrap(note,75):d.text((75,y),line,font=font(26),fill='#f4f0e7');y+=38
put(end,5*fps);end.save(p/'preview-result.jpg',quality=95)
proc.stdin.close();code=proc.wait();log.close()
if code:raise SystemExit((p/'encode.log').read_text()[-3000:])
report={'video':str(video),'seconds':count/fps,'calls':len(calls),'verdict':verdict};(p/'clip-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
