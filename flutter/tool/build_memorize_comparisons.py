"""Preserve real pixels; diagnostic equal-width overlays, never acceptance by itself."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, shutil
base = Path(__file__).resolve().parents[1]
root = base/'design-acceptance/20261026-memorize-candidate'
refs = Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
font = lambda n: ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', n)
specs = [
 ('D4-menu','04.png',(28,594,516,967),'Classic/RU, saved7-word tier, all4 lengths and both source selectors; first12 excerpts paged.',[
  'Source chips/excerpt list replace reference side navigation and split panels; layout/spacing/materials still differ.',
  'Runtime uses actual Pushkin Onegin/Raven content, not the invented author list in the generated drawing.',
  'Lengths are genuine5/7/10 words/fullstanza, not reference fictional3/6/12 lines.',
  'Full viewport/profile/theme/textscale/native acceptance remains open.']),
 ('D5-run','04.png',(550,594,1011,967),'Classic/RU, seven-word passage, pass4/5 first-letter hints, before typing.',[
  'Reference has two panels and inline completion; actual source follows five ordered passes with between-pass result.',
  'Pattern and full physical keyboard occupy one column; progress/KPI composition/materials/margins differ.',
  'Expected hidden letters are deliberately not exposed through keyboard/accessibility; original TS leaked them.',
  'Narrow-screen physical keyboard still scrolls horizontally; mobile layout remains open.']),
 ('J4-result','10.png',(54,609,484,992),'Classic/RU finalpass5/5,181WPM/100%recall/99%of firstpass; tier7→10words; automation only.',[
  'Reference structured five-pass summary/table, trophy and two-action composition are not fully implemented.',
  'Actual final metrics and accessible summary are genuine, not reference illustrative outcomes.',
  'Five per-pass results exist in personal history; final page currently emphasizes final recall/gain.',
  'Hero illustration, density, materials, typography and responsive acceptance remain open.']),
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
 for i,(img,label) in enumerate([(r,'Reference '+sheet),(a,'Actual Flutter 23a81d5'),(overlay,'50% overlay')]):
  x=20+i*(w+20);d.text((x,55),label,font=font(24),fill='#202830');panel.paste(img,(x,100))
 panel.save(out/'comparison-panel.png')
 manifest = {'screen':name,'status':'draft - substantial differences, not accepted','ownerAcceptance':None,
  'sourceCommit':'23a81d5','reference':{'path':str(reference),'sha256':sha(reference),'cropXYXY':crop,'originalSize':full.size,'logicalViewport':'unknown generated image','uniformScale':scale},
  'actual':{'sha256':sha(out/'actual.png'),'viewportCSS':[960,824],'devicePixelRatio':1,'screenshotSize':actual.size,'platform':'local Flutter web / IAB','profile':'m','language':'ru','template':'midnight-orange','brightness':'system observed dark','state':state,'url':'http://127.0.0.1:8062/?build=4fc28d6943fbf766','mainJsSha256':'4fc28d6943fbf7667ad0f3c6a0370c2198a37bceb8ae411cac99c0e8083a1fdc'},
  'method':{'equalWidth':w,'actualResized':False,'retouch':False,'warp':False,'alignment':'top-left app content','alpha':.5,'commonHeight':common,'padding':'gray outside available image pixels'},
  'limits':['Reference logical viewport/DPR unknown: diagnostic only, not device acceptance','Reference and actual metrics differ; actual figures come from automation','Other viewports/profiles/themes/native platforms remain open'],
  'differences':differences,'outputs':{n:sha(out/n) for n in ['side-by-side.png','overlay-50.png','comparison-panel.png']}}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (out/'REPORT.md').write_text('# '+name+' — draft comparison\n\nSource23a81d5. Original reference and raw actual preserved;960×824 CSS/DPR1;RU/m/midnight-orange/system dark. Equal-width uniform scaling of reference only; actual untouched;50%overlay in common area with gray padding. Reference viewport unknown.\n\n'+state+'\n\n## Remaining differences\n\n'+'\n'.join('- '+x for x in differences)+'\n\nNot owner accepted; full71screen/native/device/backend/release goal remains open.\n')
 print(name, actual.size, 'draft differences:',len(differences))
