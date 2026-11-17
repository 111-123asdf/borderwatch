"""Reproducible sprite slicing and registered layout guide. No image model substitute."""
from pathlib import Path
import json, re, shutil, hashlib
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/v017'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT.parent / '美术参考/v017原始生成'
SOURCE.mkdir(parents=True, exist_ok=True)
GEN = Path.home() / '.codex/generated_images/01a15348-fc73-7023-ba18-c17e45920c51'
FILES = {'archer':'exec-d0f64501-33fb-4b53-9e77-5d9f265939ee.png',
         'mage':'exec-f410c31a-2c4d-466b-bf0b-ae83513be7a9.png',
         'cannon':'exec-1035436e-0c44-48ab-bcc3-177d07a85baf.png',
         'barracks':'exec-6ca6ae34-63de-42de-b47b-d7568910f56f.png'}

def towers():
    manifest = {}
    for kind, name in FILES.items():
        path = GEN/name
        if not path.exists(): continue
        shutil.copy2(path, SOURCE/(kind+'.png'))
        im = Image.open(path).convert('RGBA')
        for tier in range(1,4):
            cell = im.crop(((tier-1)*im.width//3,0,tier*im.width//3,im.height))
            bounds = cell.getchannel('A').point(lambda v:255 if v>80 else 0).getbbox()
            cell = cell.crop(bounds)
            cell.thumbnail((480,480),Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA',(512,512))
            canvas.alpha_composite(cell,((512-cell.width)//2,496-cell.height))
            file = f'tower_{kind}_{tier}.png'
            canvas.save(OUT/file)
            manifest[f'{kind}{tier}']={'file':file,'contact':[256,480], 'bounds':list(canvas.getbbox()),
                                     'sha256':hashlib.sha256((OUT/file).read_bytes()).hexdigest()}
    (OUT/'towers.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

def guide():
    text = (ROOT/'scripts/arena/arena_level_catalog.gd').read_text(encoding='utf-8')
    part = text.split('if key=="ruins":')[1].split('if key=="creek":')[0]
    def vectors(s):return [tuple(map(float,p)) for p in re.findall(r'Vector2\(([-\d.]+),([-\d.]+)\)',s)]
    routes = [vectors(s) for s in re.findall(r'\[([^\[\]]+)\]',part.split('"routes":')[1].split('"bridge_gate"')[0])]
    sites = vectors(part.split('"sites":')[1].split('"site_traits"')[0])
    detour = vectors(part.split('"detour":')[1].split('"sites"')[0])
    sampled_path=ROOT/'test-results/v017-layout-curves.json'
    painted_roads=json.loads(sampled_path.read_text()) if sampled_path.exists() else routes+[detour]
    size=tuple(map(int,vectors(part.split('"size":')[1].split('"core"')[0])[0])) if '"size":' in part else (1600,900)
    im = Image.new('RGB',size,'#333d50'); d=ImageDraw.Draw(im)
    for radius,colour in [(38,'#526276'),(28,'#b0b5b6')]:
        for pts in painted_roads:
            for x,y in pts:d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=colour)
    for x,y in sites:
        d.ellipse((x-48,y-24,x+48,y+24),fill='#c8c0ad',outline='#e2d9c3',width=3)
    core=vectors(part.split('"core":')[1].split('"hero_spawn"')[0])[0]
    d.ellipse((core[0]-44,core[1]-30,core[0]+44,core[1]+30),fill='#ccbda0')
    im.save(SOURCE/'ruins-layout-guide.png')
    (OUT/'layout.json').write_text(json.dumps({'routes':routes,'detour':detour,'sites':sites,'size':list(size),'sampled':painted_roads}),encoding='utf-8')

MONSTERS={'construct_hound':'exec-a714f1b0-7599-4a5b-8fe6-eed1d66259a8.png',
          'rune_warden':'exec-458638af-416a-4895-b233-7173ac14b8b5.png',
          'astral_prism':'exec-2e6f467c-ad21-483d-a4bd-0b55f9f103d8.png',
          'rift_bomber':'exec-fb5f3120-9370-4be5-ac91-0158b0b231fd.png',
          'void_harvester':'exec-90fb0388-783c-4922-a53d-d35f080d6b82.png',
          'colossus':'exec-7c7d87b9-c596-48f7-bd41-2b269d622046.png'}

def rig_part(im, polygon):
    mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(polygon,fill=255)
    part=im.copy();part.putalpha(ImageChops.multiply(im.getchannel('A'),mask))
    return part,mask

def finish():
    map_src=GEN/'exec-b6358cb0-1c94-40d8-9d92-b58eb5982ec1.png'
    if map_src.exists():
        shutil.copy2(map_src,SOURCE/'map_ruins.png')
        layout=json.loads((OUT/'layout.json').read_text())
        size=tuple(layout['size']);opened=Image.open(map_src).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
        closed=Image.open(GEN/'exec-dedca639-79d2-495e-ac7e-1e7198127175.png').convert('RGBA').resize(size,Image.Resampling.LANCZOS)
        mask=Image.new('L',size);md=ImageDraw.Draw(mask)
        for x,y in layout['sampled'][3]:
            if x>=1340 and y<515:md.ellipse((x-80,y-80,x+80,y+80),fill=255)
        mask=mask.filter(ImageFilter.GaussianBlur(9))
        Image.composite(closed,opened,mask).convert('RGB').save(OUT/'map_ruins.png')
        opened.putalpha(mask)
        region=mask.getbbox();opened.crop(region).save(OUT/'map_ruins_open.png')
        (OUT/'art_layers.json').write_text(json.dumps({'breach_rect':[region[0],region[1],region[2]-region[0],region[3]-region[1]]}),encoding='utf-8')
    atlas=Image.new('RGBA',(2048,1536))
    for col,kind in enumerate(FILES):
        for tier in range(1,4):
            im=Image.open(OUT/f'tower_{kind}_{tier}.png').convert('RGBA')
            atlas.alpha_composite(im,(col*512,(tier-1)*512))
            # Movable part masks are local; foundations are never included.
            x0,y0,x1,y1=im.getbbox();w=x1-x0;h=y1-y0
            box={'mage':(.36,.12,.68,.45),'archer':(.31,.22,.72,.40),
                 'cannon':(.36,.08,.90,.54),'barracks':(.79,.23,.96,.52)}[kind]
            mask=Image.new('L',im.size)
            ImageDraw.Draw(mask).ellipse((x0+w*box[0],y0+h*box[1],x0+w*box[2],y0+h*box[3]),fill=255)
            part=im.copy();part.putalpha(ImageChops.multiply(im.getchannel('A'),mask))
            base=im.copy();base.putalpha(ImageChops.subtract(im.getchannel('A'),part.getchannel('A')))
            base.save(OUT/f'tower_{kind}_{tier}_base.png');part.save(OUT/f'tower_{kind}_{tier}_part.png')
    atlas.save(OUT/'towers.png')
    rigs={}
    for kind,name in MONSTERS.items():
        shutil.copy2(GEN/name,SOURCE/(kind+'.png'))
        im=Image.open(GEN/name).convert('RGBA');im=im.crop(im.getchannel('A').point(lambda v:255 if v>80 else 0).getbbox());im.thumbnail((476,476),Image.Resampling.LANCZOS)
        tile=Image.new('RGBA',(512,512));tile.alpha_composite(im,((512-im.width)//2,494-im.height));tile.save(OUT/f'actor_{kind}.png')
        x0,y0,x1,y1=tile.getbbox();w=x1-x0;h=y1-y0
        # Rigid pieces rather than stretching the entire character like a sticker.
        boxes=[(.22,.66,.48,1),(.52,.66,.82,1)]
        if kind=='construct_hound':boxes=[(.06,.48,.23,.81),(.30,.49,.44,.75),(.45,.55,.65,1),(.70,.53,.90,.87)]
        if kind=='astral_prism':boxes=[(.02,.35,.26,.73),(.73,.16,.98,.48),(.59,.66,.97,.96)]
        if kind=='void_harvester':boxes=[(.34,.68,.51,1),(.53,.66,.73,.91)]
        leg_count=len(boxes)
        if kind in ('rune_warden','colossus'):boxes += [(0,.28,.25,.78),(.76,.26,1,.75)]
        if kind=='rift_bomber':boxes += [(0,.42,.23,.77),(.78,.40,1,.75)]
        if kind=='void_harvester':boxes += [(0,0,.38,.36)]
        base=tile.copy();entries=[]
        for i,(a,b,c,d) in enumerate(boxes):
            poly=[(x0+w*a,y0+h*b),(x0+w*c,y0+h*b),(x0+w*c,y0+h*d),(x0+w*a,y0+h*d)]
            part,mask=rig_part(tile,poly)
            region=part.getbbox() or (0,0,1,1)
            part.crop(region).save(OUT/f'actor_{kind}_part{i}.png')
            base.putalpha(ImageChops.subtract(base.getchannel('A'),part.getchannel('A')))
            entries.append({'pivot':[x0+w*(a+c)/2,y0+h*b],'origin':list(region[:2]),'phase':i%2,'role':'orbit' if kind=='astral_prism' else ('leg' if i<leg_count else 'arm'),'file':f'actor_{kind}_part{i}.png'})
        base.save(OUT/f'actor_{kind}_body.png');rigs[kind]={'parts':entries,'height':h,'foot':494,'source':name}
    (OUT/'rigs.json').write_text(json.dumps(rigs,indent=2),encoding='utf-8')

if __name__=='__main__':towers();guide();finish();print('V017 art prepared')
