/* typerighting-layout-detect · VER 1 · 17.09.2026 */
/**
 * Детектор раскладки подключённой клавиатуры — задача TeamOps caaacea3, пункты 1 и 3:
 * «определять подключённую клавиатуру и её раскладку; не совпала с языком — сказать прямо,
 * а не молча учить не тем пальцам» и «схема должна соответствовать тому, что под пальцами».
 *
 * КАК. Событие клавиши несёт две вещи: e.code — ФИЗИЧЕСКОЕ место клавиши (имена по US-QWERTY:
 * KeyQ — верхний левый буквенный ряд) и e.key — что напечатала раскладка ОС. Расхождение между
 * ними и выдаёт раскладку: KeyQ→«a» бывает только у AZERTY, KeyY→«z» — только у QWERTZ.
 * navigator.keyboard.getLayoutMap() дал бы то же сразу, но его нет в Safari/WKWebView (iPad) —
 * а события с code есть везде, где есть физическая клавиатура.
 *
 * Два сигнала:
 * • physical — раскладка ОС (qwerty/azerty/qwertz) после ≥3 согласных улик и ≥80% голосов;
 * • script   — печатается не тот алфавит (текст кириллицей, а летит латиница или наоборот)
 *              в ≥4 из последних 5 буквенных нажатий. Мост (bridgeChar) при этом засчитывает
 *              нажатие по месту клавиши — но человек должен ЗНАТЬ, что у него не та раскладка.
 */
export type PhysLayout = 'qwerty' | 'azerty' | 'qwertz';
export type Script = 'latin' | 'cyrillic';

/** Улика о раскладке ОС из одного нажатия или null, если клавиша одинакова во всех трёх. */
export function layoutEvidence(code: string, key: string): PhysLayout | null {
  if (!code || !key || key.length !== 1) return null;
  const k = key.toLowerCase();
  // кириллица — ЙЦУКЕН стоит поверх QWERTY-клавиатуры, физическое место не говорит о латинской раскладке
  if (/[а-яё]/.test(k)) return null;
  switch (code) {
    case 'KeyQ': return k === 'a' ? 'azerty' : k === 'q' ? 'qwerty' : null;
    case 'KeyA': return k === 'q' ? 'azerty' : k === 'a' ? 'qwerty' : null;
    case 'KeyW': return k === 'z' ? 'azerty' : k === 'w' ? 'qwerty' : null;
    case 'KeyZ': return k === 'w' ? 'azerty' : k === 'y' ? 'qwertz' : k === 'z' ? 'qwerty' : null;
    case 'KeyY': return k === 'z' ? 'qwertz' : k === 'y' ? 'qwerty' : null;
    default: return null;
  }
}

export function scriptOf(ch: string): Script | null {
  if (/[а-яё]/i.test(ch)) return 'cyrillic';
  if (/[a-z]/i.test(ch)) return 'latin';
  return null;
}

export interface LayoutVerdict { physical: PhysLayout | null; scriptMismatch: Script | null }

export class LayoutDetector {
  private votes: Record<PhysLayout, number> = { qwerty: 0, azerty: 0, qwertz: 0 };
  private recent: boolean[] = []; // true = алфавит нажатия не совпал с ожидаемым
  private typedScript: Script | null = null;

  /** Кормим каждым печатным нажатием (ДО моста). expected — ожидаемый символ текста. */
  feed(code: string, key: string, expected: string): void {
    const ev = layoutEvidence(code, key);
    if (ev) {
      // QWERTY и QWERTZ совпадают на Q/A/W — такие клавиши голосуют за обе, чтобы не перекосить счёт
      if (ev === 'qwerty' && (code === 'KeyQ' || code === 'KeyA' || code === 'KeyW')) { this.votes.qwerty++; this.votes.qwertz++; }
      else this.votes[ev]++;
    }
    const got = scriptOf(key), want = scriptOf(expected);
    if (got && want) {
      this.recent.push(got !== want);
      if (this.recent.length > 5) this.recent.shift();
      if (got !== want) this.typedScript = got;
    }
  }

  verdict(): LayoutVerdict {
    const total = this.votes.qwerty + this.votes.azerty + this.votes.qwertz;
    let physical: PhysLayout | null = null;
    if (this.votes.azerty >= 3 && this.votes.azerty / total >= 0.8) physical = 'azerty';
    else if (this.votes.qwertz > this.votes.qwerty && this.votes.qwertz >= 3) physical = 'qwertz';
    // QWERTY подтверждается только различающими клавишами Y/Z (иначе QWERTZ голосовал бы так же)
    else if (this.votes.qwerty > this.votes.qwertz && this.votes.qwerty - this.votes.qwertz >= 2 && this.votes.azerty === 0) physical = 'qwerty';
    const mism = this.recent.filter(Boolean).length;
    const scriptMismatch = this.recent.length >= 4 && mism >= 4 ? this.typedScript : null;
    return { physical, scriptMismatch };
  }

  /** Сброс сигнала алфавита — после переключения раскладки человеком или при новом упражнении. */
  resetScript(): void { this.recent = []; this.typedScript = null; }
}
