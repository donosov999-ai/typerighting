#!/usr/bin/env python3
"""
typefree-adaptive-foreground · VER 1 · 01.10.2026 — передний слой адаптивного значка Android из src-tauri/icon-source.png.

Зачем. `npx tauri icon` кладёт в ic_launcher_foreground.png картинку во весь холст 108 dp. Android 8+ показывает
из него только середину 72 dp и режет её маской (круг, скруглённый квадрат) — от одобренного значка (клавиша T,
01.10.2026) оставалась крупная обрезанная клавиша. Здесь значок целиком ложится в середину 72 dp, а поля вокруг
и цвет фона (values/ic_launcher_background.xml) берут цвет края значка — шва под маской не видно.

Запуск после `npx tauri icon src-tauri/icon-source.png` (нужен Pillow):
    python3 scripts/android-adaptive-foreground.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / 'src-tauri'
SRC = ROOT / 'icon-source.png'
RES = ROOT / 'icons' / 'android'
SIZES = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}  # 108 dp на плотность

src = Image.open(SRC).convert('RGB')
w, h = src.size
edge = [src.getpixel((x, y)) for x in range(0, w, 8) for y in (0, h - 1)]
edge += [src.getpixel((x, y)) for y in range(0, h, 8) for x in (0, w - 1)]
color = tuple(round(sum(p[i] for p in edge) / len(edge)) for i in range(3))
hex_color = '#%02X%02X%02X' % color

for dpi, size in SIZES.items():
    inner = round(size * 72 / 108)
    canvas = Image.new('RGB', (size, size), color)
    canvas.paste(src.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    canvas.save(RES / f'mipmap-{dpi}' / 'ic_launcher_foreground.png', optimize=True)

(RES / 'values' / 'ic_launcher_background.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'  <color name="ic_launcher_background">{hex_color}</color>\n</resources>\n', encoding='utf-8')
print('foreground ×5, фон', hex_color)
