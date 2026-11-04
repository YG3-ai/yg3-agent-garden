from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import subprocess, math, wave, struct, json
p=Path(__file__).parent
out=p/'social-edit';out.mkdir(exist_ok=True)
FPS=30;SECONDS=23
font=lambda n,b=False:ImageFont.truetype('C:/Windows/Fonts/segoeui'+('b' if b else '')+'.ttf',n)
walk=p/'walk-session';view=p/'session'
cache={}
def load(file):
 key=str(file)
 if key not in cache: cache[key]=Image.open(file).convert('RGB')
 return cache[key]
def footage(t):
 if t<2.8: return load(walk/'observation-001.png')
 if t<6.4:
  j=8+min(54,int((t-2.8)*15))
  return load(walk/f'motion-{j:05d}.jpg')
 if t<12.5:
  j=63+min(91,int((t-6.4)*15))
  return load(walk/f'motion-{j:05d}.jpg')
 if t<14.6:
  j=155+min(31,int((t-12.5)*15))
  return load(walk/f'motion-{j:05d}.jpg')
 if t<16.4: return load(view/'observation-002.png')
 if t<16.85:
  return Image.blend(load(view/'observation-002.png'),load(view/'observation-003.png'),(t-16.4)/0.45)
 if t<19.8:return load(view/'observation-003.png')
 return load(view/'observation-004.png')
def copy(t):
 if t<2.8:return ['How does this space','connect to the kitchen?'],'A buyer asks. The AI takes a look.'
 if t<6.4:return ['The AI looks around.'],'It inspects the layout before answering.'
 if t<12.5:return ['One connected','living space.'],'AI answer: The dining table sits alongside the kitchen.'
 if t<14.6:return ['Then it explores','a little further.'],'From the living area into the hallway.'
 if t<16.85:return ['What does it feel like','in the evening?'],'A second question. The AI changes the lighting.'
 if t<19.8:return ['Warmer wood tones.','A cozier feel.'],'AI answer, based on the simulated evening view.'
 return ['Ask about the space.','See the AI respond.'],'An AI viewing assistant, inside a virtual home.'
def frame(t,H):
 W=1080;portrait=H==1350
 c=Image.new('RGB',(W,H),'#101c22');d=ImageDraw.Draw(c)
 role = 'BUYER ASKS' if t<2.8 or 14.6<=t<16.85 else 'AI ANSWERS' if 6.4<=t<12.5 or 16.85<=t<19.8 else 'AGENT GARDEN'
 d.text((54,30),role+'  /  HOME LAB',font=font(23,True),fill='#9abdb2')
 lines,caption=copy(t)
 size=62 if portrait else 57
 y=86 if portrait else 77
 for line in lines:d.text((54,y),line,font=font(size,True),fill='#f7f3e9');y+=size+13
 top=270 if portrait else 242
 height=810 if portrait else 610
 source=footage(t)
 image=ImageOps.fit(source,(1080,height),method=Image.Resampling.LANCZOS,centering=(0.53,0.5))
 c.paste(image,(0,top));d=ImageDraw.Draw(c)
 # One slim accent, no technical overlays.
 d.rectangle((54,top+height+35,114,top+height+39),fill='#9fcdbb')
 d.text((54,top+height+64),caption,font=font(30 if portrait else 28),fill='#f1f0e8')
 for i in range(5):
  start=[0,2.8,6.4,14.6,19.8][i];end=[2.8,6.4,14.6,19.8,23][i]
  x=54+i*196
  d.rounded_rectangle((x,H-118,x+178,H-114),radius=2,fill='#2c4249')
  if t>=start:
   frac=min(1,(t-start)/(end-start));d.rounded_rectangle((x,H-118,x+max(4,int(178*frac)),H-114),radius=2,fill='#9fcdbb')
 d.text((54,H-89),'Example buyer brief • Two AI runs • Simulated lighting',font=font(21),fill='#a8b9bf')
 d.text((54,H-53),'Apartment: Visthetique / Sketchfab / CC BY 4.0',font=font(19),fill='#829ba4')
 if t>20:
  # Full attribution accompanying the standalone clip.
  d.text((54,H-29),'Model unchanged; lighting and camera modified.',font=font(16),fill='#829ba4')
 return c
# Original, understated instrumental bed, synthesized locally.
rate=44100
with wave.open(str(out/'original-soundtrack.wav'),'wb') as wav:
 wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(rate)
 data=bytearray()
 chords=[(130.8128,164.8138,195.9977),(110.0,130.8128,164.8138),(87.3071,110.0,130.8128),(97.9989,123.4708,146.8324)]
 for n in range(rate*SECONDS):
  t=n/rate;chord=chords[min(3,int(t/6))]
  fade=min(1,t/1.2,(SECONDS-t)/1.8)
  pad=sum(math.sin(2*math.pi*f*t+0.12*math.sin(t*0.7)) for f in chord)/3*0.075
  # Soft plucked notes, rather than a prominent drum track.
  beat=int(t/0.75);phase=t-beat*0.75
  note=chord[beat%3]*2
  pluck=math.sin(2*math.pi*note*phase)*math.exp(-phase*6)*0.038
  sample=int(max(-1,min(1,(pad+pluck)*fade))*32767)
  data.extend(struct.pack('<hh',sample,sample))
 wav.writeframes(data)
for H,label in [(1350,'portrait'),(1080,'square')]:
 target=out/f'agent-garden-social-{label}.mp4'
 with (out/f'encode-{label}.log').open('w') as log:
  proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pixel_format','rgb24','-video_size',f'1080x{H}','-framerate',str(FPS),'-i','-','-i',str(out/'original-soundtrack.wav'),'-t',str(SECONDS),'-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(target)],stdin=subprocess.PIPE,stderr=log)
  for i in range(FPS*SECONDS):proc.stdin.write(frame(i/FPS,H).tobytes())
  proc.stdin.close();code=proc.wait()
 if code:raise SystemExit((out/f'encode-{label}.log').read_text()[-3000:])
 for t in [1,5,10,15.5,18,21]:frame(t,H).save(out/f'preview-{label}-{t:g}.jpg',quality=95)
 print(json.dumps({'video':str(target),'seconds':SECONDS,'width':1080,'height':H,'bytes':target.stat().st_size}),flush=True)
