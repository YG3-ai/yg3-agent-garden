from pathlib import Path
import json, subprocess, textwrap
from PIL import Image, ImageDraw, ImageFont
p=Path(__file__).parent;run=p/'walk-session'
calls=json.loads((run/'calls.json').read_text());W,H=1440,1080;fps=15
font=lambda n,b=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if b else '')+'.ttf',n)
def text(d,s,x,y,n=25,width=100,color='#e1e8ec'):
 for line in textwrap.wrap(s,width):
  d.text((x,y),line,font=font(n),fill=color);y+=n+10
 return y
def base(source,label,description):
 im=Image.open(source).convert('RGB').resize((1440,810),Image.Resampling.LANCZOS)
 c=Image.new('RGB',(W,H),'#101c24');c.paste(im,(0,110));d=ImageDraw.Draw(c)
 d.text((35,20),'AGENT GARDEN / EXPLORE THE HOME',font=font(32,True),fill='#f1f1e9')
 d.text((36,64),'Codex chooses its route from first-person images. Godot resolves each step.',font=font(22),fill='#a9bec6')
 d.rounded_rectangle((30,133,650,185),radius=9,fill='#152d35');d.text((48,143),label,font=font(24,True),fill='#bfe2d5')
 text(d,description,35,938,n=24,width=110)
 d.text((35,1014),'Actual rendered movement | Decision pauses removed | Simulated lighting | Uncalibrated model scale',font=font(19),fill='#91a9b3')
 d.text((35,1045),'Model: Modern Apartment by Visthetique / CC BY 4.0 / Sketchfab / Lighting and camera modified',font=font(17),fill='#91a9b3')
 return c
video=p/'agent-garden-home-walk.mp4'
log=(p/'walk-encode.log').open('w')
proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'{W}x{H}','-framerate',str(fps),'-i','-','-an','-vf','fps=30,format=yuv420p','-c:v','libx264','-preset','fast','-crf','20','-movflags','+faststart',str(video)],stdin=subprocess.PIPE,stderr=log)
count=0
def put(c,n=1):
 global count
 data=c.tobytes()
 for _ in range(n):proc.stdin.write(data);count+=1
intro=base(run/calls[0]['image'],'AN AI EXPLORATION, RECORDED','The agent starts in the living area and chooses where to move next.')
put(intro,3*fps)
intro.save(p/'walk-poster.jpg',quality=95)
for i,call in enumerate(calls):
 a=call['action'];args=call['args']
 if a=='move':
  label=f"{i+1:02d} / WALK {args['direction'].upper()}"
  description=f"Requested {args['distance']:g} model units. Moved {call['distance_moved']:.2f}. " + ('Stopped at an obstacle or unsupported floor.' if call.get('collision') else 'Movement clear.')
 elif a=='turn':
  label=f"{i+1:02d} / LOOK {'RIGHT' if args['degrees']>0 else 'LEFT'} {abs(args['degrees']):g}°"
  description='The agent turns to inspect the space before choosing its next action.'
 else:
  label=f'{i+1:02d} / OBSERVE';description='First-person observation. No map, coordinates, or scene tree supplied to the agent.'
 for j in range(call['clip_start'],call['clip_end']):
  c=base(run/f'motion-{j:05d}.jpg',label,description);put(c)
 put(c,8)
 if i==len(calls)//2:c.save(p/'walk-midpoint.jpg',quality=95)
end=base(run/calls[-1]['image'],'EXPLORATION NOTE','An actual agent run, preserved with observations and collision feedback.')
shade=Image.new('RGBA',end.size,(0,0,0,0));sd=ImageDraw.Draw(shade);sd.rectangle((45,300,1395,745),fill=(12,22,30,235));end=Image.alpha_composite(end.convert('RGBA'),shade).convert('RGB');d=ImageDraw.Draw(end)
d.text((80,345),'WHAT THE AGENT REPORTED',font=font(30,True),fill='#acd8cc')
summary=(run/'viewing-note.txt').read_text() if (run/'viewing-note.txt').exists() else 'Run stopped before the agent submitted a summary. See the recorded actions for its actual progress.'
text(d,summary,80,410,n=30,width=76)
put(end,6*fps);end.save(p/'walk-end.jpg',quality=95)
proc.stdin.close();code=proc.wait();log.close()
if code:raise SystemExit((p/'walk-encode.log').read_text()[-3000:])
print(json.dumps({'video':str(video),'seconds':count/fps,'observations':len(calls),'moves':sum(c['action']=='move' for c in calls),'distance_model_units':sum(c.get('distance_moved',0) for c in calls),'collisions':sum(bool(c.get('collision')) for c in calls)}))
