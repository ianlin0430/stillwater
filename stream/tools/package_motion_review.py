"""Package captured runtime frames; never changes source art."""
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[1]/'artifacts/new-model-motion-review'
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',18)
specs={
'lawnmower_blenny':([i*2 for i in range(12)],[0,2,7,10.3,13,18]),
'purple_firefish':([90+i*2 for i in range(12)],[1,3.2,5.7,8.4,11.1,17]),
'green_chromis':([75+i*5 for i in range(12)],[1,3.5,8,11.5,17,19.5]),
'yellow_tang':([1035+i*6 for i in range(12)],[2,12,22,28,31,36])}
for species,(frames,summary) in specs.items():
 folder=root/species
 subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','30','-i',str(folder/'frame-%04d.jpg'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(root/(species+'.mp4'))],check=True)
 sheet=Image.new('RGB',(1760,1440),'#122f34'); d=ImageDraw.Draw(sheet)
 for i,n in enumerate(frames):
  frame=Image.open(folder/f'frame-{n:04d}.jpg')
  x=(i%4)*440;y=(i//4)*480
  sheet.paste(frame.crop((230,80,670,300)),(x,y+24))
  sheet.paste(frame.crop((230,400,670,620)),(x,y+252))
  d.text((x+8,y+2),f'{n/30:.2f}s  BEFORE / AFTER  1.65x',font=font,fill='white')
 sheet.save(root/(species+'-frames.png'))
 board=Image.new('RGB',(1800,1920),'#122f34')
 for i,t in enumerate(summary):
  frame=Image.open(folder/f'frame-{int(t*30):04d}.jpg')
  board.paste(frame,((i%2)*900,(i//2)*640))
 board.save(root/(species+'-comparison.png'))
 print(species,flush=True)
