"""Пакет визуального сравнения по DESIGN_COMPARISON_ACCEPTANCE.md (метод Дениса 25.10.2026).

python3 tool/acceptance/compare.py spec.json

spec.json: {"build": "<commit>", "out": "design-acceptance/<build>", "screens": [{
  "id": "F3-input", "sheet": "06.png", "crop": [x0,y0,x1,y1], "actual": "<png>",
  "viewport": [w,h], "dpr": 2, "state": "...", "lang": "ru", "profile": "m",
  "template": "midnight-orange", "brightness": "dark", "status": "черновик — есть расхождения",
  "rows": [["элемент","ожидается","фактически","расхождение","влияние","исправление/исключение","повторная проверка"], ...]}]}

Реф только масштабируется равномерно до ширины actual; actual не трогается и не ретушируется.
Наложение 50/50 только в общей области, ниже — серое поле. Это диагностика, не приёмка.
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REFS = Path('/Users/denisonosov/Downloads/Helper codex/typefree-flutter-design-20261024')
BASE = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def font(n):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', n)


def build(spec, sc):
    out = BASE / spec['out'] / sc['id']
    out.mkdir(parents=True, exist_ok=True)
    sheet = REFS / sc['sheet']
    shutil.copyfile(sheet, out / 'reference-sheet.png')
    shutil.copyfile(sc['actual'], out / 'actual.png')
    ref = Image.open(sheet).convert('RGB').crop(tuple(sc['crop']))
    ref.save(out / 'reference-crop.png')
    actual = Image.open(out / 'actual.png').convert('RGB')
    w = actual.width
    scale = w / ref.width
    ref = ref.resize((w, round(ref.height * scale)), Image.Resampling.LANCZOS)
    ref.save(out / 'reference-normalized.png')
    h, common = max(ref.height, actual.height), min(ref.height, actual.height)
    r = Image.new('RGB', (w, h), '#d6dadd'); r.paste(ref, (0, 0))
    a = Image.new('RGB', (w, h), '#d6dadd'); a.paste(actual, (0, 0))
    overlay = a.copy()
    overlay.paste(Image.blend(ref.crop((0, 0, w, common)), actual.crop((0, 0, w, common)), .5), (0, 0))
    overlay.save(out / 'overlay-50.png')
    side = Image.new('RGB', (2 * w + 20, h), '#eceeef'); side.paste(r, (0, 0)); side.paste(a, (w + 20, 0))
    side.save(out / 'side-by-side.png')
    panel = Image.new('RGB', (3 * w + 80, h + 120), '#eceeef')
    d = ImageDraw.Draw(panel)
    d.text((20, 12), f"{sc['id']} · {sc['status']}", font=font(26), fill='#9e3030')
    labels = [f"Эскиз {sc['sheet']}", f"Сборка {spec['build']}", 'Наложение 50/50']
    for i, (img, label) in enumerate([(r, labels[0]), (a, labels[1]), (overlay, labels[2])]):
        x = 20 + i * (w + 20)
        d.text((x, 60), label, font=font(22), fill='#202830')
        panel.paste(img, (x, 100))
    panel.save(out / 'comparison-panel.png')
    manifest = {
        'screen': sc['id'], 'status': sc['status'], 'ownerAcceptance': None,
        'sourceCommit': spec['build'],
        'reference': {'path': str(sheet), 'sha256': sha(sheet), 'cropXYXY': sc['crop'],
                      'logicalViewport': 'unknown (generated image)', 'uniformScale': round(scale, 4)},
        'actual': {'sha256': sha(out / 'actual.png'), 'viewportCSS': sc['viewport'], 'devicePixelRatio': sc.get('dpr', 2),
                   'screenshotSize': list(actual.size), 'platform': 'local Flutter web, headless Chromium',
                   'profile': sc.get('profile', 'm'), 'language': sc.get('lang', 'ru'),
                   'template': sc.get('template', 'midnight-orange'), 'brightness': sc.get('brightness', 'dark'),
                   'state': sc['state']},
        'method': {'equalWidth': w, 'actualResized': False, 'retouch': False, 'warp': False, 'alpha': .5,
                   'alignment': 'top-left of app content', 'commonHeight': common},
        'rows': sc['rows'],
        'outputs': {n: sha(out / n) for n in ['side-by-side.png', 'overlay-50.png', 'comparison-panel.png']},
    }
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    head = '| элемент | ожидается | фактически | расхождение | влияние | исправление / исключение | повторная проверка |\n|---|---|---|---|---|---|---|\n'
    rows = ''.join('| ' + ' | '.join(row) + ' |\n' for row in sc['rows'])
    (out / 'REPORT.md').write_text(
        f"# {sc['id']} — сравнение эскиза и сборки\n\n"
        f"Статус: **{sc['status']}**. Решения Дениса нет.\n\n"
        f"Сборка `{spec['build']}`, Flutter web (headless Chromium), viewport {sc['viewport'][0]}×{sc['viewport'][1]} CSS, DPR {sc.get('dpr', 2)}, "
        f"{sc.get('lang', 'ru')}/{sc.get('profile', 'm')}/{sc.get('template', 'midnight-orange')}/{sc.get('brightness', 'dark')}.\n"
        f"Эскиз: `{sc['sheet']}` вырезка {sc['crop']}, равномерный масштаб {scale:.3f}; actual не изменён. Логический размер эскиза неизвестен — сравнение диагностическое.\n\n"
        f"Состояние: {sc['state']}\n\n## Расхождения\n\n{head}{rows}\n"
        "Панель: `comparison-panel.png`, наложение: `overlay-50.png`. Наложение — диагностика, не приёмка.\n")
    print(sc['id'], actual.size, 'rows:', len(sc['rows']))


if __name__ == '__main__':
    spec = json.loads(Path(sys.argv[1]).read_text())
    for sc in spec['screens']:
        build(spec, sc)
