"""Rebuild design-acceptance/INDEX_20261028.md and PANELS_20261028/*.png.

python3 tool/acceptance/index.py   (from flutter/)

Run after EVERY new package — the index and sheets must point at the latest
package of each screen (Codex review 28.10: D5 was stale).
Latest = newest package folder (by name) containing that screen's manifest.
The «Открытые вопросы» section of the existing index is kept as is.
"""
import glob
import json
import os
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / 'design-acceptance'
GROUPS = {'A': '1_A_главные', 'F': '2_F_I_прогресс_настройки_тема', 'I': '2_F_I_прогресс_настройки_тема',
          'M': '3_M_синапс', 'B': '4_B_тренажёр', 'C': '5_C_J_библиотека_курс_режимы',
          'J': '5_C_J_библиотека_курс_режимы', 'D': '6_D_E_режимы', 'E': '6_D_E_режимы', 'K': '7_K_сертификат'}


def key_of(screen):
    return screen.split(' ')[0].split('-')[0].split('·')[0].strip()


def main():
    os.chdir(ROOT)
    rows, others = [], []
    for m in sorted(glob.glob('*/*/manifest.json')):
        d = json.load(open(m))
        if 'sourceCommit' in d and 'status' in d:
            rows.append((d['screen'], d['status'], d['sourceCommit'], os.path.dirname(m)))
        else:
            others.append(os.path.dirname(m))
    others += [p.rstrip('/') for p in sorted(glob.glob('2*/*/')) if not os.path.exists(p + 'manifest.json')]
    old = Path('INDEX_20261028.md').read_text() if Path('INDEX_20261028.md').exists() else ''
    tail = old[old.index('## Открытые вопросы'):] if '## Открытые вопросы' in old else '## Открытые вопросы\n'
    seen = {}
    for s, st, b, p in rows:
        seen.setdefault(s, []).append((st, b, p))
    out = ['# TypeFree Flutter — пакеты сравнения дизайна (индекс)', '',
           'Собирается `tool/acceptance/index.py` после каждого пакета. Метод: DESIGN_COMPARISON_ACCEPTANCE.md. Листы по группам: PANELS_20261028/.',
           'Статусы — самопроверка исполнителя; **решения Дениса нет ни по одному экрану**.', '',
           '| экран | статус | сборка | пакет |', '|---|---|---|---|']
    for s in sorted(seen):
        items = sorted(seen[s], key=lambda x: x[2])
        for st, b, p in items:
            hist = '' if p == items[-1][2] else ' (история)'
            out.append(f'| {s} | {st}{hist} | `{b}` | [{p}]({p}/REPORT.md) |')
    out += ['', 'Пакеты Codex 25–26.10 (свой формат):', ''] + [f'- `{p}`' for p in sorted(set(others))] + ['', tail]
    Path('INDEX_20261028.md').write_text('\n'.join(out))
    latest = {}
    for m in sorted(glob.glob('*/*/manifest.json')):
        d = json.load(open(m))
        key = key_of(d.get('screen') or os.path.basename(os.path.dirname(m)))
        folder = os.path.dirname(m)
        if key not in latest or folder.split('/')[0] >= latest[key][0]:
            latest[key] = (folder.split('/')[0], folder, d.get('status', '?'))
    by, lines = {}, []
    for key, (_, folder, st) in sorted(latest.items()):
        g = GROUPS.get(key[0])
        if g and os.path.exists(f'{folder}/comparison-panel.png'):
            by.setdefault(g, []).append((key, folder, st))
    os.makedirs('PANELS_20261028', exist_ok=True)
    for g, items in sorted(by.items()):
        ims = []
        for key, folder, st in items:
            im = Image.open(f'{folder}/comparison-panel.png').convert('RGB')
            im.thumbnail((1500, 700))
            ims.append(im)
            lines.append(f'{key} · {st} · {folder}')
        sheet = Image.new('RGB', (max(i.width for i in ims), sum(i.height for i in ims) + 24 * len(ims)), '#c9cdd1')
        y = 0
        for im in ims:
            sheet.paste(im, (0, y))
            y += im.height + 24
        sheet.save(f'PANELS_20261028/{g}.png', optimize=True)
    Path('PANELS_20261028/README.md').write_text(
        '# Листы сравнения для приёмки [Claude·MAC]\n\nПоследняя панель каждого экрана: эскиз | сборка | наложение 50/50. '
        'Таблица — REPORT.md пакета. Решения Дениса нет.\n\n' + '\n'.join('- ' + l for l in lines) + '\n')
    stat = {}
    for _, (_, _, st) in latest.items():
        stat[st.split(' ')[0]] = stat.get(st.split(' ')[0], 0) + 1
    print(len(rows), 'packages;', len(latest), 'screens;', stat)


if __name__ == '__main__':
    main()
