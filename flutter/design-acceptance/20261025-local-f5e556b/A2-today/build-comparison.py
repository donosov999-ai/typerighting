from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import shutil,hashlib,json
root=Path('/Users/denisonosov/dev/typerighting-wt-flutter-20261025/flutter/design-acceptance/20261025-local-f5e556b/A2-today')
src=Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024/01.png')
shutil.copyfile(src,root/'reference-sheet.png')
full=Image.open(src).convert('RGB'); actual=Image.open(root/'actual.png').convert('RGB')
# A2 only; exclude device bezel and illustrated OS status bar. No app content is removed.
crop=(604,70,932,520)
reference=full.crop(crop);reference.save(root/'reference-crop.png')
w=actual.width; h=actual.height
scale=w/reference.width; ref=reference.resize((w,round(reference.height*scale)),Image.Resampling.LANCZOS)
ref.save(root/'reference-normalized.png');actual.save(root/'actual-normalized.png')
common=min(ref.height,h)
overlay=actual.copy();overlay.paste(Image.blend(ref.crop((0,0,w,common)),actual.crop((0,0,w,common)),.5),(0,0));overlay.save(root/'overlay-50.png')
background='#eceeef'; ink='#202830';muted='#52616d'
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
font=lambda n:ImageFont.truetype(font_path,n)
W=3*w+80;top=132;H=top+h+160
panel=Image.new('RGB',(W,H),background);d=ImageDraw.Draw(panel)
d.text((20,14),'TypeFree · «Сегодня»: референс и фактическая сборка',font=font(25),fill=ink)
d.text((20,50),'A2 «Сегодня» реализован · визуальная приёмка ещё не подтверждена.',font=font(19),fill='#b32e2e')
labels=[('Референс A2 «Сегодня»','01.png · контентная область'),('Собранный экран «Сегодня»','Flutter web · f5e556b'),('Наложение 50/50','Одинаковый экран · 50/50')]
for i,(title,sub) in enumerate(labels):
 x=20+i*(w+20);d.text((x,86),title,font=font(17),fill=ink);d.text((x,111),sub,font=font(13),fill=muted)
canvas=Image.new('RGB',(w,h),'#d6dadd');canvas.paste(ref,(0,0))
panel.paste(canvas,(20,top));panel.paste(actual,(40+w,top));panel.paste(overlay,(60+2*w,top))
d=ImageDraw.Draw(panel)
if ref.height<h:
 d.text((32,top+ref.height+20),'Здесь референс заканчивается.',font=font(14),fill=muted)
 d.text((32,top+ref.height+44),'Высота не растянута под сборку.',font=font(14),fill=muted)
y=top+h+15
lines=[
 'Реализованы: пейзаж, запуск тренировки, продолжение курса, серия дней и последний результат.',
 'Навигация: «Сегодня / Практика / Прогресс / Ещё». Значения взяты из сохранённой истории.',
 f'Ширина одинакова: {w}px. Референс: {w}×{ref.height}; сборка: {w}×{h}. Без растягивания осей.',
 'Overlay действует только там, где есть оба изображения; ниже — только скриншот сборки.',
 'Локальный Flutter web · RU · midnight-orange · system → dark · viewport 320×582 · DPR 2.',
 'Отличаются текст, иллюстрация, метрики и пропорции. Статус: черновик; решение Дениса отсутствует.'
]
for line in lines:d.text((20,y),line,font=font(14),fill=ink);y+=22
panel.save(root/'comparison-panel.png')
side=Image.new('RGB',(2*w+20,h),background);side.paste(canvas,(0,0));side.paste(actual,(w+20,0));side.save(root/'side-by-side.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'date':'2026-10-25','timezone':'Asia/Almaty','screen':'A2 Today','reference':{'sheet':str(src),'sha256':sha(src),'originalSize':full.size,'cropXYXY':crop,'cropPurpose':'exclude illustrated phone frame/status chrome; keep all A2 app content','logicalViewport':'unknown: generated concept sheet','uniformScale':scale,'normalizedSize':ref.size},'actual':{'path':str(root/'actual.png'),'sha256':sha(root/'actual.png'),'url':'http://127.0.0.1:8062/','screen':'Today / default start','sourceImplementationCommit':'f5e556b','checkoutHead':'f5e556b','artifact':'local web build, not a store build','viewportCSS':[320,582],'screenshotSize':actual.size,'devicePixelRatio':2,'language':'ru','htmlLanguage':'en-US','profile':'m','template':'midnight-orange','brightnessSetting':'system','resolvedBrightness':'dark','textScale':'not independently measured; no test override made'},'normalization':{'align':'content top-left','sameWidth':w,'actualScale':1,'alpha':.5,'commonOverlayHeight':common,'outsideOverlap':'actual pixels retained; no reference pixels invented','warping':False,'retouching':False},'status':'draft - Today implemented; remaining differences documented; not accepted','userAcceptance':None,'limits':['reference contains illustrative values; no logical viewport/DPR metadata','reference statistics are illustrative; actual values come from local automated test sessions','narrow window only; this is not full desktop or mobile device acceptance'],'outputs':{n:sha(root/n) for n in ['comparison-panel.png','side-by-side.png','overlay-50.png']}}
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
