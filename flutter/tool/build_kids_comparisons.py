"""Preserve real pixels; diagnostic equal-width overlays, never acceptance by itself."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, shutil
base = Path(__file__).resolve().parents[1]
root = base/'design-acceptance/20261026-kids-candidate'
refs = Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
font = lambda n: ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', n)
specs = [
 ('D2-map','04.png',(546,112,1012,528),'RU/m child course after reload: level1 has three saved stars, level2 open, levels3–33 locked.',[
  'Reference illustrated winding map/landscape and hero are not implemented; actual exposes all33 source levels in two language groups.',
  'Original source has9RU+24EN levels; the generated10-node map is not the authoritative lesson count.',
  'Spacing, materials, illustrated progress route and explicit ordinary-practice CTA remain open; global Back returns to all practices.',
  'Reference viewport/DPR unknown; equal-width overlay is diagnostic, not owner or device acceptance.']),
 ('J3-result','10.png',(1063,58,1495,504),'Automated real keyboard entry of котдомсоклесмяч: five words, three stars, saved locally; auto-next paused.',[
  'Original accuracy-first kids course does not show speed. Generated126characters/min is not copied as an unmeasured result.',
  'Actual retains the original blue typing cat; orange illustrated hero/confetti/materials/geometry are not implemented.',
  'Source-compatible retry/map/next and optional auto-next controls are present; reference separate ordinary-practice and break actions need design work.',
  'Soft rest after three levels is widget-tested; this actual screenshot shows only the first completed level.',
  'Audio/voice and full native/mobile/theme/profile/accessibility design acceptance remain open.']),
]
for name, sheet, crop, state, differences in specs:
 reference = refs/sheet
 out = root/name
 shutil.copyfile(reference, out/'reference-sheet.png')
 full = Image.open(reference).convert('RGB')
 ref = full.crop(crop); ref.save(out/'reference-crop.png')
 actual = Image.open(out/'actual.png').convert('RGB')
 assert actual.size == (960,824), actual.size
 w = actual.width; scale = w/ref.width
 ref = ref.resize((w,round(ref.height*scale)), Image.Resampling.LANCZOS)
 ref.save(out/'reference-normalized.png'); actual.save(out/'actual-normalized.png')
 h = max(ref.height,actual.height); common = min(ref.height,actual.height)
 r = Image.new('RGB',(w,h),'#d6dadd'); r.paste(ref,(0,0))
 a = Image.new('RGB',(w,h),'#d6dadd'); a.paste(actual,(0,0))
 overlay = a.copy(); overlay.paste(Image.blend(ref.crop((0,0,w,common)),actual.crop((0,0,w,common)),.5),(0,0))
 overlay.save(out/'overlay-50.png')
 side = Image.new('RGB',(2*w+20,h),'#eceeef'); side.paste(r,(0,0));side.paste(a,(w+20,0));side.save(out/'side-by-side.png')
 panel = Image.new('RGB',(3*w+80,h+160),'#eceeef');d=ImageDraw.Draw(panel)
 d.text((20,10),name+' - DRAFT, substantial differences; NOT accepted',font=font(28),fill='#9e3030')
 for i,(img,label) in enumerate([(r,'Reference '+sheet),(a,'Actual Flutter 12a0033'),(overlay,'50% overlay')]):
  x=20+i*(w+20);d.text((x,55),label,font=font(24),fill='#202830');panel.paste(img,(x,100))
 panel.save(out/'comparison-panel.png')
 manifest = {'screen':name,'status':'draft - substantial differences, not accepted','ownerAcceptance':None,
  'sourceCommit':'12a0033','reference':{'path':str(reference),'sha256':sha(reference),'cropXYXY':crop,'originalSize':full.size,'logicalViewport':'unknown generated image','uniformScale':scale},
  'actual':{'sha256':sha(out/'actual.png'),'viewportCSS':[960,824],'devicePixelRatio':1,'screenshotSize':actual.size,'platform':'local Flutter web / IAB','profile':'m','language':'ru','template':'midnight-orange','brightness':'system observed dark','state':state,'url':'http://127.0.0.1:8062/?build=a254a2ee1e77fe31','mainJsSha256':'a254a2ee1e77fe31471838a76b54fc8b697643ddfa5b0787954eb17a221b3797'},
  'method':{'equalWidth':w,'actualResized':False,'retouch':False,'warp':False,'alignment':'top-left app content','alpha':.5,'commonHeight':common,'padding':'gray outside available image pixels'},
  'limits':['Reference logical viewport/DPR unknown: diagnostic only, not device acceptance','Reference and actual metrics differ; actual figures come from automation','Other viewports/profiles/themes/native platforms remain open'],
  'differences':differences,'outputs':{n:sha(out/n) for n in ['side-by-side.png','overlay-50.png','comparison-panel.png']}}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (out/'REPORT.md').write_text('# '+name+' — draft comparison\n\nSource12a0033. Original reference and raw actual preserved;960×824 CSS/DPR1;RU/m/midnight-orange/system dark. Equal-width uniform scaling of reference only; actual untouched;50%overlay in common area with gray padding. Reference viewport unknown.\n\n'+state+'\n\n## Remaining differences\n\n'+'\n'.join('- '+x for x in differences)+'\n\nNot owner accepted; full71screen/native/device/backend/release goal remains open.\n')
 print(name, actual.size, 'draft differences:',len(differences))
