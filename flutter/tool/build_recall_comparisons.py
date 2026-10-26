"""Preserve real pixels; diagnostic equal-width overlays, never acceptance by itself."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, shutil
base = Path(__file__).resolve().parents[1]
root = base/'design-acceptance/20261026-recall-candidate'
refs = Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
font = lambda n: ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', n)
specs = [
 ('J5-menu','10.png',(557,607,1009,990),'RU/m start menu:span3,best reached next-set4 retained from previous automated round.',[
  'Reference has word-preview chips and illustrated hero; source menu chooses fresh random words only at Start.',
  'Actual layout currently uses a plain summary card and localized explanation of next-set record.',
  'Materials/typography/geometry and all theme/profile/textscale/native states remain open.']),
 ('D6-show','04.png',(1046,595,1508,968),'RU/m reveal phase:помогло рядом команда,three actual words,3600ms automatic hide.',[
  'Reference has word cards/sidebar; actual retains the source single pattern field between reveal and recall.',
  'Actual full physical keyboard preserves original keys; generated compact drawing omits some.',
  'Hidden phase must not highlight or announce expected letters; reveal/hidden screenshots are separate truthful states.',
  'Narrow740px keyboard still scrolls horizontally; responsive composition/materials need work.']),
 ('J6-result','10.png',(1066,608,1497,991),'Completed3actualwords:100%characteraccuracy,3stars,nextspan4,best4; auto-next paused; automation only.',[
  'Reference per-word checklist/illustration/split result panel not yet implemented; actual shows true character accuracy and completed/next span.',
  'Source blocked input ultimately completes every word; cannot copy reference4of5correct as an unmeasured fact.',
  'Record is the reached next challenge, not completed length; actual label explains this source rule.',
  'Typography/cards/spacing/visual feedback/full responsive acceptance remain open.']),
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
 for i,(img,label) in enumerate([(r,'Reference '+sheet),(a,'Actual Flutter a017daa'),(overlay,'50% overlay')]):
  x=20+i*(w+20);d.text((x,55),label,font=font(24),fill='#202830');panel.paste(img,(x,100))
 panel.save(out/'comparison-panel.png')
 manifest = {'screen':name,'status':'draft - substantial differences, not accepted','ownerAcceptance':None,
  'sourceCommit':'a017daa','reference':{'path':str(reference),'sha256':sha(reference),'cropXYXY':crop,'originalSize':full.size,'logicalViewport':'unknown generated image','uniformScale':scale},
  'actual':{'sha256':sha(out/'actual.png'),'viewportCSS':[960,824],'devicePixelRatio':1,'screenshotSize':actual.size,'platform':'local Flutter web / IAB','profile':'m','language':'ru','template':'midnight-orange','brightness':'system observed dark','state':state,'url':'http://127.0.0.1:8062/?build=1e6f6ab2bf45f297','mainJsSha256':'1e6f6ab2bf45f297384a23ee1e80e4e90fd1825cc3bf858ac066ede8753a05d2'},
  'method':{'equalWidth':w,'actualResized':False,'retouch':False,'warp':False,'alignment':'top-left app content','alpha':.5,'commonHeight':common,'padding':'gray outside available image pixels'},
  'limits':['Reference logical viewport/DPR unknown: diagnostic only, not device acceptance','Reference and actual metrics differ; actual figures come from automation','Other viewports/profiles/themes/native platforms remain open'],
  'differences':differences,'outputs':{n:sha(out/n) for n in ['side-by-side.png','overlay-50.png','comparison-panel.png']}}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (out/'REPORT.md').write_text('# '+name+' — draft comparison\n\nSourcea017daa. Original reference and raw actual preserved;960×824 CSS/DPR1;RU/m/midnight-orange/system dark. Equal-width uniform scaling of reference only; actual untouched;50%overlay in common area with gray padding. Reference viewport unknown.\n\n'+state+'\n\n## Remaining differences\n\n'+'\n'.join('- '+x for x in differences)+'\n\nNot owner accepted; full71screen/native/device/backend/release goal remains open.\n')
 print(name, actual.size, 'draft differences:',len(differences))
