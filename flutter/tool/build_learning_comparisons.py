"""Deterministic reference/actual overlays; never redraw or retouch either image."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib,json,shutil
base=Path(__file__).resolve().parents[1]
root=base/'design-acceptance/20261026-learning-candidate'
refs=Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
font=lambda n:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
specs=[
 ('D1-learning','D1 · AI-обучение','04.png',(32,115,516,529),(960,824),'m',
  'Новая взрослая сессия, 0 завершённых строк; исходник не содержит вымышленных прогресс-баров по рукам.',
  ['Композиция: сейчас одна колонка, в рисунке основная область и правая панель.',
   'KPI сейчас ниже полной клавиатуры, в рисунке выше текста; отличаются шапка, материалы и отступы.',
   'Физическая клавиатура сохраняет 5 рядов/Shift/Enter из исходника; generated компактная схема неполна.',
   'Рисунок содержит иллюстративные значения/шкалы; переносить их как настоящую статистику нельзя.',
   'One-hand visual dimming и общие звук/voice/SFX ещё не приняты; это не завершение full AI задачи.']),
 ('D3-child-learning','D3 · Детское AI','04.png',(1047,115,1507,529),(960,824),'kids',
  'Настоящий исходный уровень 1, очки 0, без взрослого табло скорости; оригинальные cat frames.',
  ['Hero/иллюстрация/правая панель и геометрия не совпадают с рисунком.',
   'Использованы неизменённые исходные статические кадры кота; новый рисунок не подменяет общий Synapse renderer.',
   'Истинная первая RU-ступень содержит А/О; generated рисунок показывает другой состав букв/указания рук.',
   'Полная клавиатура и реальные метрики сохранены; audio/celebration effects остаются глобальной задачей.']),
 ('C6-weak-keys','C6 · Слабые клавиши','03.png',(1044,612,1448,1014),(320,582),'m',
  'Живые общие per-key данные устройства после автоматического smoke input; числа не являются результатом Дениса.',
  ['Высота/плотность не соответствуют C6: большая клавиатура требует горизонтальной прокрутки на узком экране.',
   'Кнопка генерации и последние результаты ниже первого viewport; требуется исправить мобильную композицию.',
   'Заголовок обрезается рядом с обязательными настройками/языком/Synapse; нужен reflow.',
   'Показаны только существующие слабые буквы и последние original/plain результаты; отсутствие результата — прочерк.'])]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for folder,title,sheet,crop,viewport,profile,state,differences in specs:
 out=root/folder;out.mkdir(parents=True,exist_ok=True)
 shutil.copyfile(refs/sheet,out/'reference-sheet.png')
 full=Image.open(out/'reference-sheet.png').convert('RGB');actual=Image.open(out/'actual.png').convert('RGB')
 assert actual.size==viewport,(folder,actual.size,viewport)
 reference=full.crop(crop);reference.save(out/'reference-crop.png')
 w=actual.width;scale=w/reference.width
 reference=reference.resize((w,round(reference.height*scale)),Image.Resampling.LANCZOS);reference.save(out/'reference-normalized.png')
 actual.save(out/'actual-normalized.png');h=max(actual.height,reference.height);common=min(actual.height,reference.height)
 ref_canvas=Image.new('RGB',(w,h),'#d6dadd');ref_canvas.paste(reference,(0,0))
 act_canvas=Image.new('RGB',(w,h),'#d6dadd');act_canvas.paste(actual,(0,0))
 overlay=act_canvas.copy();overlay.paste(Image.blend(reference.crop((0,0,w,common)),actual.crop((0,0,w,common)),.5),(0,0));overlay.save(out/'overlay-50.png')
 top=110;panel=Image.new('RGB',(3*w+80,top+h+100),'#eceeef');d=ImageDraw.Draw(panel)
 heading=font(20 if w<500 else 30);label=font(15 if w<500 else 24);small=font(12 if w<500 else 18)
 d.text((20,10),title+' · reference / actual / 50% overlay',font=heading,fill='#202830')
 d.text((20,48),'ЧЕРНОВИК: есть существенные расхождения. Приёмка Дениса отсутствует.',font=small,fill='#b32e2e')
 for i,(image,label_text) in enumerate([(ref_canvas,'Референс · '+sheet),(act_canvas,'Реальная сборка · 8d7be68'),(overlay,'Наложение 50/50')]):
  x=20+i*(w+20);d.text((x,80),label_text,font=label,fill='#202830');panel.paste(image,(x,top))
 d=ImageDraw.Draw(panel);d.text((20,top+h+12),'Равномерная нормализация ширины; actual не растянут и не ретуширован.',font=small,fill='#202830')
 d.text((20,top+h+40),'Серые поля — отсутствие пикселей исходника. Overlay только в общей области.',font=small,fill='#202830')
 panel.save(out/'comparison-panel.png')
 side=Image.new('RGB',(2*w+20,h),'#eceeef');side.paste(ref_canvas,(0,0));side.paste(act_canvas,(w+20,0));side.save(out/'side-by-side.png')
 manifest={'date':'2026-10-26','screen':title,'sourceCommit':'8d7be68','reference':{'path':str(refs/sheet),'sha256':sha(refs/sheet),'originalSize':full.size,'cropXYXY':crop,'cropPurpose':'exclude drawn device border/status chrome, preserve app content','logicalViewport':'unknown generated mockup','uniformScale':scale,'normalizedSize':reference.size},'actual':{'sha256':sha(out/'actual.png'),'viewportCSS':viewport,'screenshotSize':actual.size,'devicePixelRatio':1,'platform':'local Flutter web / in-app browser','template':'midnight-orange','brightness':'system, observed dark','language':'ru','profile':profile,'textScale':'not independently measured; desktop default','url':'http://127.0.0.1:8062/?build=7e8511b43ba3b6e5','verifiedMainJsSha256':'7e8511b43ba3b6e5db72ba4658588ffc0f60a0a1a0b1c59b631a724f28e0d33f','state':state},'normalization':{'actualResized':False,'align':'content top-left','sameWidth':w,'overlayAlpha':.5,'commonHeight':common,'padding':'gray outside either image; no invented image pixels','retouch':False,'warp':False},'status':'draft - differences; NOT accepted','ownerAcceptance':None,'differences':differences,'limits':['Reference viewport/DPR are unknown, so this is a diagnostic comparison not exact-device acceptance','Illustrative reference metrics differ from genuine local test data','Full screen/device/theme/profile acceptance remains open'],'outputs':{n:sha(out/n) for n in ['side-by-side.png','overlay-50.png','comparison-panel.png']}}
 (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (out/'REPORT.md').write_text('# '+title+' — draft comparison\n\nSource8d7be68; local web mainJS7e8511b43ba3b6e5. Reference '+str(refs/sheet)+'; actual screenshot preserved unchanged.\n\nViewport '+str(viewport)+', DPR1, RU, profile '+profile+', midnight-orange/system→dark. Reference logical viewport/DPR unknown; crop + uniform equal-width scaling only; no actual resizing/warping/retouch. Overlay50% only common area; original files and hashes in manifest.json.\n\nState: '+state+'\n\n## Remaining differences\n\n'+'\n'.join('- '+x for x in differences)+'\n\nStatus: **draft; not owner-accepted**. Test/build/store readiness is not visual acceptance. Other screens/full native update/backend/release remain in FULL_TRANSFER_SCOPE_20261026.md.\n')
 print(folder,actual.size,'draft differences:',len(differences))
