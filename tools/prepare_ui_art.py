"""User-authorized UI matte cleanup, component crop/normalization; retain originals.

Optional authoring dependencies only: Pillow, numpy, OpenCV. Runtime uses PNG/JSON.
"""
from pathlib import Path
import hashlib
import json
import cv2
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]
manifest_path=root/'docs/ART_GENERATION_V013.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
for item in manifest['assets']:
    original=Path(item['original'])
    source=original if original.exists() else root/item['file']
    if not source.exists():raise RuntimeError('Both original output and project PNG are unavailable')
    # The cleanup is idempotent; teammates can regenerate crops from distributed PNGs.
    image=Image.open(source).convert('RGBA')
    if item.get('transparent'):
        rgba=np.array(image)
        # No magenta was requested in the final generation: real alpha is preferred.
        # Clear only invisible fringe pixels, preserving colored spell/rarity artwork.
        rgba[rgba[:,:,3]<8]=0
        image=Image.fromarray(rgba)
    image.save(root/item['file'])
    item['sha256']=hashlib.sha256((root/item['file']).read_bytes()).hexdigest()
    item['processing']='RGBA preserved; alpha < 8 cleared (user-authorized edge cleanup)' if item.get('transparent') else 'Original RGB unchanged; RGBA PNG encoding'

skin={'dark':[26,25,572,274], 'paper':[644,41,569,251], 'card':[104,335,428,494],
      'green':[637,358,576,142], 'blue':[636,511,576,143], 'amber':[636,665,577,144]}
regions={'ui_skin':skin}
for sheet,columns,rows in [('ui_icons',4,4),('ui_controls',4,4),('perk_icons',8,5)]:
    image=Image.open(root/f'assets/v013/{sheet}.png').convert('RGBA');a=np.array(image)[:,:,3]
    width,height=image.size;frames={}
    for index in range(columns*rows):
        left=round(index%columns*width/columns);right=round((index%columns+1)*width/columns)
        top=round(index//columns*height/rows);bottom=round((index//columns+1)*height/rows)
        mask=(a[top:bottom,left:right]>32).astype('uint8')
        count,labels,stats,centers=cv2.connectedComponentsWithStats(mask)
        components=[s for s in stats[1:] if s[4]>80]
        if not components:raise RuntimeError(f'Missing {sheet} cell {index}')
        x,y,w,h,area=max(components,key=lambda s:s[4])
        x0=max(left,left+int(x)-4);y0=max(top,top+int(y)-4)
        x1=min(right,left+int(x+w)+4);y1=min(bottom,top+int(y+h)+4)
        frames[str(index)]=[x0,y0,x1-x0,y1-y0]
    regions[sheet]=frames
image=Image.open(root/'assets/v013/ui_skin.png')
for name in ['dark','paper','green','blue','amber']:
    x,y,w,h=skin[name];widget=image.crop((x,y,x+w,y+h));widget=widget.resize((320,round(320*h/w)),Image.Resampling.LANCZOS)
    widget.save(root/f'assets/v013/widget_{name}.png')
(root/'assets/v013/regions.json').write_text(json.dumps(regions,indent=2)+'\n',encoding='utf-8')
manifest['derived']='Five cropped/normalized 320px-wide widgets from ui_skin; same authored borders, distinct panel/button slices. 16+16+40 inspected icon regions. No third-party image imported.'
manifest['derived_assets']=[{'file':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted((root/'assets/v013').glob('widget_*.png'))]
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('UI alpha edges cleaned; 72 icon regions and five normalized widget textures prepared')
