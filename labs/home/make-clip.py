import json, textwrap, subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
p=Path(__file__).parent
run=p/'session'
calls=json.loads((run/'calls.json').read_text())
notes={}
last=0
for line in (run/'codex-events.jsonl').read_text().splitlines():
 try: e=json.loads(line)
 except ValueError: continue
 item=e.get('item',{})
 if e.get('type')=='item.completed' and item.get('type')=='mcp_tool_call' and item.get('tool') in ['observe','turn','set_lighting']: last+=1
 if e.get('type')=='item.completed' and item.get('type')=='agent_message' and last: notes[last]=item.get('text','')
font=lambda size,bold=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if bold else '')+'.ttf',size)
W,H=1440,1080
out=p/'clip-frames';out.mkdir(exist_ok=True)
timeline=[]
def wrapped(d,text,xy,width=96,size=26,color='#e4e9ef'):
 x,y=xy
 for line in textwrap.wrap(text,width):
  d.text((x,y),line,font=font(size),fill=color);y+=size+10
 return y
def base(image):
 c=Image.new('RGB',(W,H),'#101c24')
 c.paste(Image.open(run/image).convert('RGB').resize((1440,810),Image.Resampling.LANCZOS),(0,110))
 d=ImageDraw.Draw(c)
 d.text((35,20),'AGENT GARDEN / HOME LAB',font=font(32,True),fill='#f1f1e9')
 d.text((36,64),'A buyer question. An AI viewing assistant. An interactive apartment.',font=font(22),fill='#a9bec6')
 d.text((35,1014),'Actual Codex tool observations | Pauses shortened | Simulated lighting | Fixed camera position',font=font(19),fill='#91a9b3')
 d.text((35,1045),'Model: Modern Apartment by Visthetique / CC BY 4.0 / Sketchfab / Lighting and camera modified',font=font(17),fill='#91a9b3')
 return c,d
c,d=base(calls[0]['image'])
shade=Image.new('RGBA',c.size,(0,0,0,0));sd=ImageDraw.Draw(shade);sd.rectangle((0,310,W,650),fill=(12,22,30,225));c=Image.alpha_composite(c.convert('RGBA'),shade).convert('RGB');d=ImageDraw.Draw(c)
d.text((70,355),'BEFORE THE SHOWING',font=font(28,True),fill='#acd8cc')
wrapped(d,'“How does the living room connect to the kitchen, and what does it feel like in the evening?”',(70,415),width=55,size=38)
wrapped(d,'The assistant looks around, changes the lights, and reports what it can see.',(35,942),width=105,size=25)
c.save(out/'000.png');timeline.append(('000.png',4))
for i,call in enumerate(calls,1):
 c,d=base(call['image'])
 labels={'observe':'01 / INSPECT THE LIVING SPACE','turn':'LOOK AROUND','set_lighting':'SWITCH TO EVENING'}
 label=labels[call['action']]
 if call['action']=='turn': label=f"LOOK {'RIGHT' if call['args']['degrees']>0 else 'LEFT'} / {abs(call['args']['degrees']):g}°"
 d.rounded_rectangle((30,133,520,185),radius=9,fill='#152d35')
 d.text((48,143),label,font=font(24,True),fill='#bfe2d5')
 text=notes.get(i, 'Inspecting the rendered apartment.')
 if len(text)>205: text=text[:202].rsplit(' ',1)[0]+'...'
 wrapped(d,text,(35,935),width=107,size=24)
 name=f'{i:03d}.png';c.save(out/name);timeline.append((name,5))
c,d=base(calls[-1]['image'])
shade=Image.new('RGBA',c.size,(0,0,0,0));sd=ImageDraw.Draw(shade);sd.rectangle((40,265,1400,760),fill=(12,22,30,235));c=Image.alpha_composite(c.convert('RGBA'),shade).convert('RGB');d=ImageDraw.Draw(c)
d.text((80,305),'A VIEWING NOTE, GROUNDED IN THE SCENE',font=font(30,True),fill='#acd8cc')
summary=(run/'viewing-note.txt').read_text()
wrapped(d,summary,(80,375),width=76,size=30)
wrapped(d,'A prototype for interactive property viewing, powered by images and tools.',(35,942),width=105,size=25)
name=f'{len(calls)+1:03d}.png';c.save(out/name);timeline.append((name,7))
lines=[]
for name,duration in timeline: lines.extend([f"file 'clip-frames/{name}'",f'duration {duration}'])
lines.append(f"file 'clip-frames/{timeline[-1][0]}'")
(p/'clip-concat.txt').write_text('\n'.join(lines)+'\n')
video=p/'agent-garden-home-viewing.mp4'
r=subprocess.run(['ffmpeg','-y','-f','concat','-safe','0','-i',str(p/'clip-concat.txt'),'-t',str(sum(x[1] for x in timeline)),'-vf','fps=24,format=yuv420p','-c:v','libx264','-crf','19','-movflags','+faststart',str(video)],capture_output=True,text=True)
if r.returncode: raise SystemExit(r.stderr[-3000:])
print(json.dumps({'video':str(video),'seconds':sum(x[1] for x in timeline),'observations':len(calls),'bytes':video.stat().st_size}))
