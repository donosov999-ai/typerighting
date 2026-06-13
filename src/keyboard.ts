// Интерактивная SVG-клавиатура — векторная копия схемы из оригинального
// TypeRIGHTing (public/images/keyboard.jpg, 920×380): раскладка ЙЦУКЕН↔QWERTY,
// красные стрелки = правильное НАПРАВЛЕНИЕ ДВИЖЕНИЯ пальца от домашнего ряда.
// Интерактив: подсветка следующей клавиши + стрелки её маршрута; для
// заглавных/символов дополнительно подсвечивается Shift противоположной руки.

interface KeyDef {
  id: string;     // стабильный id (латиница)
  u: number;      // ширина в юнитах
  en?: string;    // основная EN-гравировка (низ слева)
  en2?: string;   // shift-гравировка EN (верх слева)
  ru?: string;    // RU-гравировка (низ справа, красным)
  label?: string; // спец-клавиши (Tab, Shift...)
}

// ── Раскладка (как в оригинале, включая ретро-клавишу Rept) ──
const ROWS: KeyDef[][] = [
  [
    { id: 'tilde', u: 1, en: '~', en2: '`', ru: 'Ё' },
    { id: 'd1', u: 1, en: '1', en2: '!' }, { id: 'd2', u: 1, en: '2', en2: '@' },
    { id: 'd3', u: 1, en: '3', en2: '#' }, { id: 'd4', u: 1, en: '4', en2: '$' },
    { id: 'd5', u: 1, en: '5', en2: '%' }, { id: 'd6', u: 1, en: '6', en2: '^' },
    { id: 'd7', u: 1, en: '7', en2: '&' }, { id: 'd8', u: 1, en: '8', en2: '*' },
    { id: 'd9', u: 1, en: '9', en2: '(' }, { id: 'd0', u: 1, en: '0', en2: ')' },
    { id: 'minus', u: 1, en: '-', en2: '_' }, { id: 'equal', u: 1, en: '=', en2: '+' },
    { id: 'backslash', u: 1, en: '\\', en2: '|' },
    { id: 'backspace', u: 1.6, label: '←' },
  ],
  [
    { id: 'tab', u: 1.5, label: 'Tab' },
    { id: 'q', u: 1, en: 'Q', ru: 'Й' }, { id: 'w', u: 1, en: 'W', ru: 'Ц' },
    { id: 'e', u: 1, en: 'E', ru: 'У' }, { id: 'r', u: 1, en: 'R', ru: 'К' },
    { id: 't', u: 1, en: 'T', ru: 'Е' }, { id: 'y', u: 1, en: 'Y', ru: 'Н' },
    { id: 'u', u: 1, en: 'U', ru: 'Г' }, { id: 'i', u: 1, en: 'I', ru: 'Ш' },
    { id: 'o', u: 1, en: 'O', ru: 'Щ' }, { id: 'p', u: 1, en: 'P', ru: 'З' },
    { id: 'lbracket', u: 1, en: '[', en2: '{', ru: 'Х' },
    { id: 'rbracket', u: 1, en: ']', en2: '}', ru: 'Ъ' },
    { id: 'enterpad2', u: 1.45 }, // призрачная зона под высокий Enter
  ],
  [
    { id: 'caps', u: 1.9, label: 'Caps Lock' },
    { id: 'a', u: 1, en: 'A', ru: 'Ф' }, { id: 's', u: 1, en: 'S', ru: 'Ы' },
    { id: 'd', u: 1, en: 'D', ru: 'В' }, { id: 'f', u: 1, en: 'F', ru: 'А' },
    { id: 'g', u: 1, en: 'G', ru: 'П' }, { id: 'h', u: 1, en: 'H', ru: 'Р' },
    { id: 'j', u: 1, en: 'J', ru: 'О' }, { id: 'k', u: 1, en: 'K', ru: 'Л' },
    { id: 'l', u: 1, en: 'L', ru: 'Д' },
    { id: 'semi', u: 1, en: ';', en2: ':', ru: 'Ж' },
    { id: 'quote', u: 1, en: "'", en2: '"', ru: 'Э' },
    { id: 'enterpad3', u: 1.45 }, // призрачная зона под высокий Enter
  ],
  [
    { id: 'lshift', u: 2.3, label: 'Shift' },
    { id: 'z', u: 1, en: 'Z', ru: 'Я' }, { id: 'x', u: 1, en: 'X', ru: 'Ч' },
    { id: 'c', u: 1, en: 'C', ru: 'С' }, { id: 'v', u: 1, en: 'V', ru: 'М' },
    { id: 'b', u: 1, en: 'B', ru: 'И' }, { id: 'n', u: 1, en: 'N', ru: 'Т' },
    { id: 'm', u: 1, en: 'M', ru: 'Ь' },
    { id: 'comma', u: 1, en: ',', en2: '<', ru: 'Б' },
    { id: 'period', u: 1, en: '.', en2: '>', ru: 'Ю' },
    { id: 'slash', u: 1, en: '/', en2: '?' },
    { id: 'rshift', u: 1.2, label: 'Shift' },
    { id: 'rept', u: 1.2, label: 'Rept' },
  ],
  [
    { id: 'lctrl', u: 1.3, label: 'Ctrl' }, { id: 'blank1', u: 1.1 },
    { id: 'lalt', u: 1.3, label: 'Alt' },
    { id: 'space', u: 6.8, label: '' },
    { id: 'ralt', u: 1.3, label: 'Alt' }, { id: 'blank2', u: 1.1 },
    { id: 'rctrl', u: 1.3, label: 'Ctrl' },
  ],
];

// ── Стрелки оригинала: от домашней клавиши → куда движется палец (29 шт) ──
// Снято с public/images/keyboard.jpg. Цифровой ряд в оригинале покрыт
// частично (5,6,7,8) — оставлено как есть; добавить пару = одна строка.
const ARROWS: Array<[string, string]> = [
  ['a', 'q'], ['a', 'z'],
  ['s', 'w'], ['s', 'x'],
  ['d', 'e'], ['d', 'c'],
  ['f', 'r'], ['f', 't'], ['f', 'g'], ['f', 'v'], ['f', 'b'], ['f', 'd5'],
  ['j', 'y'], ['j', 'u'], ['j', 'h'], ['j', 'n'], ['j', 'm'], ['j', 'd6'], ['j', 'd7'],
  ['k', 'i'], ['k', 'comma'], ['k', 'd8'],
  ['l', 'o'], ['l', 'period'],
  ['semi', 'p'], ['semi', 'lbracket'], ['semi', 'rbracket'], ['semi', 'quote'], ['semi', 'slash'],
];

// Домашняя клавиша пальца для каждой целевой (для подсветки маршрута)
const HOME_OF: Record<string, string> = {};
for (const [from, to] of ARROWS) HOME_OF[to] = from;

// Клавиши ЛЕВОЙ руки (колонки 1–5: до T/G/B и цифры 1–5 включительно).
// Для них Shift берётся правый, и наоборот. Явное множество — граница рук
// не совпадает с геометрической серединой клавиатуры (T/Y, G/H, B/N).
const LEFT_HAND = new Set([
  'tilde', 'd1', 'd2', 'd3', 'd4', 'd5',
  'tab', 'q', 'w', 'e', 'r', 't',
  'caps', 'a', 's', 'd', 'f', 'g',
  'lshift', 'z', 'x', 'c', 'v', 'b',
]);

// ── Геометрия (viewBox 920×380, как оригинал) ──
const W = 920, H = 380, PAD = 12, GAP = 6, KEY_H = 60, PITCH = 70, TOP = 14;

interface KeyGeo extends KeyDef { x: number; y: number; w: number; h: number }
const GEO: Record<string, KeyGeo> = {};
{
  ROWS.forEach((row, r) => {
    const units = row.reduce((s, k) => s + k.u, 0);
    const uw = (W - 2 * PAD - GAP * (row.length - 1)) / units;
    let x = PAD;
    for (const k of row) {
      const w = k.u * uw;
      GEO[k.id] = { ...k, x, y: TOP + r * PITCH, w, h: KEY_H };
      x += w + GAP;
    }
  });
  // Enter — высокий (ISO-стиль, ряды 2–3) в зоне призрачных паддингов
  const p2 = GEO['enterpad2'], p3 = GEO['enterpad3'];
  const ex = Math.min(p2.x, p3.x);
  GEO['enter'] = { id: 'enter', u: 0, label: 'Enter', x: ex, y: p2.y, w: W - PAD - ex, h: p3.y + KEY_H - p2.y };
  delete GEO['enterpad2'];
  delete GEO['enterpad3'];
}

// ── Маппинг символ → клавиша ──
interface KeyHit { id: string; shift: boolean }
const EN_MAP: Record<string, KeyHit> = {};
const RU_MAP: Record<string, KeyHit> = {};
{
  const add = (m: Record<string, KeyHit>, ch: string, id: string, shift: boolean) => { m[ch] = { id, shift }; };
  for (const g of Object.values(GEO)) {
    if (g.en) {
      if (/^[A-Z]$/.test(g.en)) { add(EN_MAP, g.en.toLowerCase(), g.id, false); add(EN_MAP, g.en, g.id, true); }
      else { add(EN_MAP, g.en, g.id, false); if (g.en2) add(EN_MAP, g.en2, g.id, true); }
    }
    if (g.ru && /^[А-ЯЁ]$/.test(g.ru)) { add(RU_MAP, g.ru.toLowerCase(), g.id, false); add(RU_MAP, g.ru, g.id, true); }
  }
  // RU-пунктуация (ЙЦУКЕН): точка на «/?», запятая = Shift там же
  add(RU_MAP, '.', 'slash', false); add(RU_MAP, ',', 'slash', true);
  for (const m of [EN_MAP, RU_MAP]) { add(m, ' ', 'space', false); add(m, '\n', 'enter', false); }
  // Цифры и общие символы работают в обоих раскладках
  for (const [ch, hit] of Object.entries(EN_MAP)) if (!(ch in RU_MAP) && !/[a-zA-Z.,]/.test(ch)) RU_MAP[ch] = hit;
}

// ── Мост раскладок: одна физическая клавиша — две буквы (EN↔RU) ──
// Если ожидается кириллица, а раскладка ОС латинская (или наоборот),
// нажатие правильной ФИЗИЧЕСКОЙ клавиши засчитывается.
const EN_TO_RU: Record<string, string> = {};
const RU_TO_EN: Record<string, string> = {};
for (const row of ROWS) for (const k of row) {
  if (k.en && k.ru && /^[A-Z]$/.test(k.en) && /^[А-ЯЁ]$/.test(k.ru)) {
    EN_TO_RU[k.en.toLowerCase()] = k.ru.toLowerCase();
    RU_TO_EN[k.ru.toLowerCase()] = k.en.toLowerCase();
  }
}

/** Перевести введённый символ в алфавит ожидаемого по физической клавише. */
export function bridgeChar(input: string, expected: string): string {
  if (input.length !== 1 || expected.length !== 1) return input;
  const lower = input.toLowerCase();
  let mapped: string | undefined;
  if (/[а-яё]/i.test(expected) && /[a-z]/.test(lower)) mapped = EN_TO_RU[lower];
  else if (/[a-z]/i.test(expected) && /[а-яё]/.test(lower)) mapped = RU_TO_EN[lower];
  if (!mapped) return input;
  return input === lower ? mapped : mapped.toUpperCase();
}

export function findKey(ch: string, ruContext: boolean): KeyHit | null {
  if (/[а-яё]/i.test(ch)) return RU_MAP[ch] ?? null;
  if (/[a-z]/i.test(ch)) return EN_MAP[ch] ?? null;
  return (ruContext ? RU_MAP[ch] : EN_MAP[ch]) ?? (ruContext ? EN_MAP[ch] : RU_MAP[ch]) ?? null;
}

/** Буквенные клавиши (для адаптивного режима «слабые клавиши»). */
export function letterKeys(lang: 'en' | 'ru'): Array<{ id: string; ch: string }> {
  const out: Array<{ id: string; ch: string }> = [];
  for (const g of Object.values(GEO)) {
    const ch = lang === 'en' ? g.en : g.ru;
    if (ch && /^[A-Za-zА-Яа-яЁё]$/.test(ch)) out.push({ id: g.id, ch: ch.toLowerCase() });
  }
  return out;
}

/** id физической клавиши для символа (для сбора per-key статистики). */
export function keyIdFor(ch: string, ruContext: boolean): string | null {
  return findKey(ch, ruContext)?.id ?? null;
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
const cx = (g: KeyGeo) => g.x + g.w / 2;
const cy = (g: KeyGeo) => g.y + g.h / 2;

function arrowPath(from: KeyGeo, to: KeyGeo): string {
  const x1 = cx(from), y1 = cy(from), x2 = cx(to), y2 = cy(to);
  // лёгкий изгиб перпендикулярно направлению (как нарисовано в оригинале)
  const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
  const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy) || 1;
  const bend = Math.min(18, len * 0.18) * (dx >= 0 ? 1 : -1);
  const qx = mx - (dy / len) * bend, qy = my + (dx / len) * bend;
  // не доводим до центра целевой клавиши, чтобы остриё было видно
  const t = 1 - 16 / len;
  const ex = x1 + dx * t, ey = y1 + dy * t;
  return `M ${x1.toFixed(1)} ${y1.toFixed(1)} Q ${qx.toFixed(1)} ${qy.toFixed(1)} ${ex.toFixed(1)} ${ey.toFixed(1)}`;
}

/**
 * SVG-клавиатура. nextChar — следующий символ упражнения (null = без подсветки),
 * ruContext — упражнение русское (для неоднозначных . и ,),
 * showRu — рисовать ли русский слой букв (false = чистая QWERTY для EN-рынка).
 */
export function keyboardSVG(nextChar: string | null, ruContext: boolean, showRu = true, heat: Record<string, number> | null = null): string {
  const hit = nextChar !== null ? findKey(nextChar, ruContext) : null;
  const targetId = hit?.id ?? null;
  const homeId = targetId ? (HOME_OF[targetId] ?? null) : null;
  // Shift противоположной руки: цель у левой руки → правый Shift, и наоборот
  let shiftId: string | null = null;
  if (hit?.shift && targetId) shiftId = LEFT_HAND.has(targetId) ? 'rshift' : 'lshift';

  const parts: string[] = [];
  for (const g of Object.values(GEO)) {
    const cls = ['key'];
    if (g.id === targetId) cls.push('key-next');
    if (g.id === shiftId) cls.push('key-shift');
    if (g.id === homeId) cls.push('key-home');
    const fx = (g.x + 4).toFixed(1), fy = g.y + 3, fw = (g.w - 8).toFixed(1), fh = g.h - 10;
    parts.push(`<g class="${cls.join(' ')}" data-key="${g.id}">`,
      `<rect class="key-base" x="${g.x}" y="${g.y}" width="${g.w.toFixed(1)}" height="${g.h}" rx="9"/>`,
      `<rect class="key-face" x="${fx}" y="${fy}" width="${fw}" height="${fh}" rx="6"/>`);
    // тепловая карта: errRate 0 = освоено (зелёный), >0 = слабая (красный по величине)
    if (heat && g.id in heat) {
      const sev = heat[g.id];
      const fill = sev <= 0 ? '34,197,94' : '217,58,58';
      const op = sev <= 0 ? 0.22 : (0.2 + 0.6 * Math.min(sev, 1)).toFixed(2);
      parts.push(`<rect x="${fx}" y="${fy}" width="${fw}" height="${fh}" rx="6" fill="rgb(${fill})" opacity="${op}"/>`);
    }
    if (g.label !== undefined) {
      parts.push(`<text class="key-fn" x="${cx(g).toFixed(1)}" y="${(cy(g) + 4).toFixed(1)}" text-anchor="middle">${esc(g.label)}</text>`);
    } else {
      if (g.en2) parts.push(`<text class="key-en2" x="${(g.x + 12).toFixed(1)}" y="${g.y + 22}">${esc(g.en2)}</text>`);
      if (g.en) parts.push(`<text class="key-en" x="${(g.x + 12).toFixed(1)}" y="${g.y + (g.en2 ? 46 : 38)}">${esc(g.en)}</text>`);
      if (g.ru && showRu) parts.push(`<text class="key-ru" x="${(g.x + g.w - 12).toFixed(1)}" y="${g.y + g.h - 14}" text-anchor="end">${esc(g.ru)}</text>`);
    }
    parts.push('</g>');
  }

  const arrows = ARROWS.map(([from, to]) => {
    const active = to === targetId && from === (homeId ?? '');
    return `<path class="arr${active ? ' arr-active' : ''}" d="${arrowPath(GEO[from], GEO[to])}" marker-end="url(#arrhead${active ? '-a' : ''})"/>`;
  }).join('');

  return `<svg class="kbsvg${targetId ? ' has-target' : ''}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Схема клавиатуры: красные стрелки — правильное направление движения пальцев от домашнего ряда">
    <defs>
      <marker id="arrhead" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto"><path d="M0,0 L7,3.5 L0,7 Z" class="arrhead"/></marker>
      <marker id="arrhead-a" markerWidth="8" markerHeight="8" refX="5.5" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" class="arrhead-a"/></marker>
    </defs>
    <rect class="kb-bg" x="0" y="0" width="${W}" height="${H}" rx="14"/>
    ${parts.join('')}
    ${arrows}
  </svg>`;
}
