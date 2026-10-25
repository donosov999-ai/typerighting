from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import shutil,hashlib,json
root=Path('/Users/denisonosov/dev/typerighting-wt-flutter-20261025/flutter/design-acceptance/20261025-local-1a6c0ef/A2-today-missing')
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
d.text((20,50),'НЕ ПРИНЯТО: экран A2 «Сегодня» ещё не реализован.',font=font(19),fill='#b32e2e')
labels=[('Референс A2 «Сегодня»','01.png · контентная область'),('Собранный стартовый экран','Тренажёр вместо «Сегодня»'),('Наложение 50/50','Разные экраны — расхождение')]
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
 'Не реализованы: карточка дня/иллюстрация, «Начать тренировку», продолжение курса и сводка дня.',
 'Навигация отличается: в сборке нет разделов «Сегодня» и «Ещё».',
 f'Ширина одинакова: {w}px. Референс: {w}×{ref.height}; сборка: {w}×{h}. Без растягивания осей.',
 'Overlay действует только там, где есть оба изображения; ниже — только скриншот сборки.',
 'Локальный Flutter web · RU · midnight-orange · system → dark · viewport 320×582 · DPR 2.',
 'Это фиксация отсутствующего экрана; сравнение одинакового состояния пока невозможно.'
]
for line in lines:d.text((20,y),line,font=font(14),fill=ink);y+=22
panel.save(root/'comparison-panel.png')
side=Image.new('RGB',(2*w+20,h),background);side.paste(canvas,(0,0));side.paste(actual,(w+20,0));side.save(root/'side-by-side.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'date':'2026-10-25','timezone':'Asia/Almaty','screen':'A2 Today','reference':{'sheet':str(src),'sha256':sha(src),'originalSize':full.size,'cropXYXY':crop,'cropPurpose':'exclude illustrated phone frame/status chrome; keep all A2 app content','logicalViewport':'unknown: generated concept sheet','uniformScale':scale,'normalizedSize':ref.size},'actual':{'path':str(root/'actual.png'),'sha256':sha(root/'actual.png'),'url':'http://127.0.0.1:8062/','screen':'ordinary practice / default start, Today route absent','sourceImplementationCommit':'1a6c0ef','checkoutHead':'0dc155cbfbda5f14b0f46b55444ab00f39b762c8','artifact':'local web build, not a store build','viewportCSS':[320,582],'screenshotSize':actual.size,'devicePixelRatio':2,'language':'ru','htmlLanguage':'en-US','profile':'m','template':'midnight-orange','brightnessSetting':'system','resolvedBrightness':'dark','textScale':'not independently measured; no test override made'},'normalization':{'align':'content top-left','sameWidth':w,'actualScale':1,'alpha':.5,'commonOverlayHeight':common,'outsideOverlap':'actual pixels retained; no reference pixels invented','warping':False,'retouching':False},'status':'draft - Today not implemented; same-state visual acceptance blocked','userAcceptance':None,'limits':['reference contains illustrative values; no logical viewport/DPR metadata','actual is different screen because target route is not implemented','narrow window only; this is not full desktop or mobile device acceptance'],'outputs':{n:sha(root/n) for n in ['comparison-panel.png','side-by-side.png','overlay-50.png']}}
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(root/'REPORT.md').write_text('''# A2 «Сегодня» — сравнение 25.10.2026

**Статус: черновик; целевой экран не реализован. Визуальная приёмка не пройдена.**

Референс A2: `reference-sheet.png`, исходный01.png; сборка: реально запущенный локальный Flutter web на http://127.0.0.1:8062/ . Реализация1a6c0ef, HEAD0dc155c содержит только документационное дополнение. Скриншот `actual.png` — настоящий текущий стартовый тренажёр, не имитация отсутствующей страницы. Никакие пользовательские данные/настройки не менялись; для съёмки закрыт диалог настроек без применения и открыт существующий раздел тренировки.

| Элемент | Референс | Реальная сборка | Итог |
|---|---|---|---|
| Маршрут/заголовок | Сегодня | TypeFree → тренажёр | A2 не реализован, сравнение одноимённого состояния невозможно |
| Карточка дня | Иллюстрация, приветствие, CTA | Отсутствует | Существенное отличие композиции |
| Продолжение курса | Карточка на главной | Курс существует отдельным разделом, карточки на старте нет | Нет предусмотренного входа с A2 |
| Сводка дня | Серия/последний результат | Отсутствует | Не подставлять условные12/92/98изрисунка как реальные данные |
| Нижняя навигация | Сегодня/Практика/Прогресс/Ещё | Тренировка/Прогресс/Курс | Состав и информационная архитектура различаются |
| Синапс | В этом раннем A2 не нарисован; поздний реф требует лицо в header | Есть canonical face | Позднее уточнение учитывать отдельно, реф под actual не перерисовывать |
| Размеры | Crop328×450, равномерно до320×439 | Viewport/screenshot320×582 | Нижняя пустота в reference-панели показывает отсутствие исходных пикселей, не частьUI |

В `comparison-panel.png`: реф, actual иoverlay50/50. Наложение применено только к общей области320×439; ниже показан actual без придуманных reference-пикселей. Все координаты/хеши/масштабы в manifest.json. Оригиналы сохранены. Текст/условные метрики рефа не перенесены в данные приложения.

Следующее: реализовать настоящий маршрутA2 по согласованному рефу, сохранив функции; снять его на согласованном viewport и с безопасным реальным состоянием, повторить сравнение. Текущий пакет не может статьPASS только из-за похожей палитры. Решения Дениса о приёмке нет.
''')
print(root/'comparison-panel.png');print('size',panel.size,'reference normalized',ref.size)
