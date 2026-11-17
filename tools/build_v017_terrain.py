"""Collision derives from painted abyss, with authored road/site clearance."""
from pathlib import Path
import json, math
from PIL import Image
R=Path(__file__).resolve().parents[1];O=R/'assets/v017'
im=Image.open(O/'map_ruins.png').convert('RGB')
layout=json.loads((O/'layout.json').read_text());roads=layout['routes']+[layout['detour']]
def distance(p,a,b):
 dx=b[0]-a[0];dy=b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/max(1,dx*dx+dy*dy)))
 return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
blocks=[]
for y in range(0,im.height-19,20):
 row=[]
 for x in range(0,im.width-19,20):
  point=(x+10,y+10);blue=0
  for dy in [3,7,12,16]:
   for dx in [3,7,12,16]:
    r,g,b=im.getpixel((x+dx,y+dy));blue+=int(b>r*1.30 and b>g*1.06 and r<115)
  road_dist=min(distance(point,a,b) for road in roads for a,b in zip(road,road[1:]))
  row.append(blue>=12 and road_dist>52 and min(math.dist(point,p) for p in layout['sites'])>62)
 run=None
 for x,value in enumerate(row+[False]):
  if value and run is None:run=x
  if not value and run is not None:blocks.append([run*20,y,(x-run)*20,20]);run=None
(O/'terrain_blocks.json').write_text(json.dumps(blocks),encoding='utf-8')
print('Painted abyss collision rectangles:',len(blocks))
