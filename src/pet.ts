/* typerighting-pet · VER 1 · 17.09.2026 */
/**
 * Питомец в приложении — задача TeamOps 46d1207f (сайт-часть в проде с 02.08).
 *
 * ИСТОЧНИК: public/mascot/ заполняет scripts/fetch-mascot.mjs при сборке (npm prebuild/predev) —
 *   с публичного CDN mascot.asibots.pro, версии закреплены: движок 1.1.10 (+патч tr1), пак
 *   typerighting 1.0.10 (pack.json + idle/type/wave). В репо НЕ лежит: mascot-engine — PRIVATE,
 *   а это репо публичное. Локально (не в сборке): приложению нужен офлайн и CSP script-src 'self',
 *   поэтому файлы едут внутри бандла, а не грузятся с CDN в рантайме.
 *   ref/ (2,6 МБ референсов) не качаем: pack.image грузится только у static-паков, у спрайтового — нет.
 *   Сжатие с потерями отвергнуто замером: pngquant — код 99 (256 цветов не держат качество 75).
 *   ⚠️ Смена версий — константы в fetch-mascot.mjs + ENGINE_VER ниже.
 *
 * ПРАВИЛА ИЗ ЗАДАЧИ.
 * • Не лезет в зону набора и МОЛЧИТ во время сессии: виден только в меню, на экране результатов
 *   теста и в режиме телефона. На экране тренажёра не появляется никогда (клавиатура там на месте),
 *   рекорд оттуда говорится при следующем появлении. Скрытый — движок спит (не жжёт кадры).
 * • Говорит ДЕЛОМ — реплика из статистики (pickLine ниже), а не «Гуляю тут…».
 * • Тумблер в настройках (tr_pet); prefers-reduced-motion движок гасит сам.
 * • Детский режим: у kids.ts свой котик, взрослый питомец там скрыт (единый движок — позже,
 *   решение записано в задаче).
 */
import { weakKeys, recoveryKeys, forecast, streakDays, history, onSession } from './stats-store';
import { t, lang } from './i18n';

interface PetApi {
  el: HTMLElement;
  say(text: string, ms?: number): PetApi;
  sleep(): PetApi;
  wake(): PetApi;
  destroy(): void;
}
interface BiryuzikGlobal { init(opts: Record<string, unknown>): PetApi }

const PREF_KEY = 'tr_pet';
/** Версия вендор-копии движка — в адресе скрипта: иначе после обновления браузер/вебвью берёт
 *  старый biryuzik.js из кэша (поймано 17.09 при проверке патча: сервер отдавал новый, страница — старый). */
const ENGINE_VER = '1.1.10-tr1';
const STREAK_SAID_KEY = 'tr_pet_streak';
/** Пороги стрика: отмечаем их, а не каждый день — иначе похвала обесценится (условие задачи). */
export const STREAK_MARKS = [3, 7, 14, 30, 60, 100];

export function petEnabled(): boolean {
  try { return localStorage.getItem(PREF_KEY) !== '0'; } catch { return true; }
}

// ── Что сказать: чистая функция, покрыта тестами ──
export interface PetFacts {
  record: number | null;          // WPM только что поставленного рекорда
  recovery: string[];             // клавиши, просевшие от своего рекорда
  streak: number;                 // дней подряд
  streakSaid: number;             // какой порог уже отметили
  forecast: { sessions: number; target: number; certainty: number } | null;
  weak: string[];                 // слабые клавиши сейчас
}
export type PetLine = { key: string; text: string; streakMark?: number };

const fill = (s: string, vars: Record<string, string | number>) =>
  s.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? String(vars[k]) : `{${k}}`));
const keysText = (ks: string[]) => ks.map((k) => k.toUpperCase()).join(' ');

export function pickLine(f: PetFacts, tr: (key: string) => string = t): PetLine {
  if (f.record !== null) return { key: 'pet.record', text: fill(tr('pet.record'), { wpm: f.record }) };
  if (f.recovery.length >= 2) return { key: 'pet.recovery', text: fill(tr('pet.recovery'), { keys: keysText(f.recovery) }) };
  const mark = [...STREAK_MARKS].reverse().find((m) => f.streak >= m);
  if (mark && mark > f.streakSaid) return { key: 'pet.streak', text: fill(tr('pet.streak'), { n: f.streak }), streakMark: mark };
  if (f.forecast && f.forecast.certainty >= 0.5 && f.forecast.sessions > 0 && f.forecast.sessions <= 60) {
    return { key: 'pet.forecast', text: fill(tr('pet.forecast'), { n: f.forecast.sessions, target: f.forecast.target }) };
  }
  if (f.weak.length >= 3) return { key: 'pet.weak', text: fill(tr('pet.weak'), { keys: keysText(f.weak.slice(0, 3)) }) };
  return { key: 'pet.hello', text: tr('pet.hello') };
}

/**
 * Рекорд ловим В МОМЕНТ конца сессии (событие onSession), а говорим о нём при следующем
 * появлении питомца. Почему не сразу: после упражнения в тренажёре это тот же экран набора —
 * клавиатура на месте, человек жмёт Enter к следующему, а питомец в первой версии сел поверх
 * клавиши Enter на схеме (кадр 17.09). «Не лезет в зону набора» важнее «показать на результате».
 */
let pendingRecord: number | null = null;
export function notePossibleRecord(wpm: number, hist: { wpm: number }[] = history()): void {
  // pushHistory сохраняет точку ДО события, поэтому последняя в истории — это и есть эта сессия
  if (hist.length < 2) return;
  const prevBest = Math.max(...hist.slice(0, -1).map((p) => p.wpm));
  if (wpm > prevBest) pendingRecord = Math.max(pendingRecord ?? 0, wpm);
}

/** Факты из настоящей статистики; отложенный рекорд забирается один раз. */
export function collectFacts(now = Date.now()): PetFacts {
  const L = lang() === 'ru' ? 'ru' : 'en'; // буквенные наборы статистики — латиница или кириллица
  const record = pendingRecord;
  pendingRecord = null;
  let streakSaid = 0;
  try { streakSaid = Number(localStorage.getItem(STREAK_SAID_KEY)) || 0; } catch { /* */ }
  return {
    record,
    recovery: recoveryKeys(L, 3),
    streak: streakDays(now),
    streakSaid,
    forecast: forecast(),
    weak: weakKeys(L, 6),
  };
}

// ── Монтирование и видимость ──
let pet: PetApi | null = null;
let loading: Promise<void> | null = null;
let shown = false;
let greetedThisRun = false;

function loadEngine(): Promise<void> {
  const g = window as unknown as { Biryuzik?: BiryuzikGlobal };
  if (g.Biryuzik) return Promise.resolve();
  if (loading) return loading;
  loading = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = `./mascot/biryuzik.js?v=${ENGINE_VER}`;
    s.onload = () => resolve();
    s.onerror = () => { loading = null; reject(new Error('mascot engine')); };
    document.head.appendChild(s);
  });
  return loading;
}

function narrow(): boolean {
  try { return window.matchMedia('(max-width: 600px)').matches; } catch { return false; }
}

async function ensurePet(): Promise<PetApi | null> {
  if (pet) return pet;
  try { await loadEngine(); } catch { return null; }
  const g = window as unknown as { Biryuzik?: BiryuzikGlobal };
  if (!g.Biryuzik || pet) return pet;
  pet = g.Biryuzik.init({
    lang: lang() === 'ru' ? 'ru' : 'en',
    id: 'tr-pet',
    size: narrow() ? 84 : 110,
    pack: './mascot/typerighting',
    roam: false,
    chatter: false,
    lines: [t('pet.hello')],
    // Справа: слева внизу живёт кнопка багфикса, а текст карточек выровнен влево — у правого края
    // пустое поле. Первая раскладка без x села влево поверх кнопки и текста карточки (кадр 17.09).
    // Число больше ширины экрана — движок сам прижимает к правому краю (maxX); opts.x важнее
    // сохранённой позиции.
    x: 100000,
    bottom: narrow() ? 76 : 24,
  });
  pet.el.classList.add('tr-pet-host');
  return pet;
}

/** Подписка при старте приложения: рекорд запоминается в момент конца любой сессии. */
export function initPet(): void {
  onSession((e) => notePossibleRecord(e.wpm));
}

/**
 * Вызывается первым в render(). visible — можно ли показывать на этом экране (решает main.ts:
 * меню, режим телефона, экран результатов теста; экран набора — никогда).
 */
export function petSync(visible: boolean): void {
  if (!petEnabled()) { if (pet) { pet.destroy(); pet = null; } shown = false; return; }
  if (!visible) {
    if (pet && shown) { pet.el.style.display = 'none'; pet.sleep(); }
    shown = false;
    return;
  }
  const becameVisible = !shown;
  shown = true;
  void ensurePet().then((p) => {
    if (!p || !shown) return;
    p.el.style.display = '';
    p.wake();
    // Говорим только на входе на экран: есть свежий рекорд — всегда, иначе — раз за запуск.
    if (!becameVisible) return;
    if (pendingRecord === null && greetedThisRun) return;
    greetedThisRun = true;
    const line = pickLine(collectFacts());
    if (line.streakMark) { try { localStorage.setItem(STREAK_SAID_KEY, String(line.streakMark)); } catch { /* */ } }
    p.say(line.text, 6000);
  });
}
