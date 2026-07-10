// F1 озвучка: проговаривание букв/цифр при вводе. Аудио — офлайн-семплы Silero TTS,
// предгенерированы на Contabo-FR, лежат в public/audio/<lang>/.
// RU: имя файла = Unicode-код буквы (а=1072..я=1103, ё=1105), цифра = 'd'+цифра (голос xenia, v4_ru).
// EN: имя файла = код латинской буквы (a=97..z=122), произносится ИМЯ буквы ("ay","bee"…),
// цифра = 'd'+цифра, произносится словом ("zero".."nine") — голос en_0, v3_en.
// es/de/fr/it/pt — озвучки пока нет (fileFor вернёт null, канал молчит).
import { lang } from './i18n';

let voiceOn = false;
try { voiceOn = localStorage.getItem('tr_voice') === '1'; } catch { /* */ }

export function setVoiceEnabled(on: boolean) {
  voiceOn = on;
  try { localStorage.setItem('tr_voice', on ? '1' : '0'); } catch { /* */ }
}
export function voiceEnabled(): boolean { return voiceOn; }

/** Языки, для которых есть офлайн-семплы озвучки букв/цифр. */
export const VOICED_LANGS = new Set(['ru', 'en']);

const cache = new Map<string, HTMLAudioElement>();

function fileFor(ch: string): string | null {
  if (!ch) return null;
  const l = lang();
  if (!VOICED_LANGS.has(l)) return null;
  if (ch >= '0' && ch <= '9') return 'd' + ch;
  const code = ch.toLowerCase().charCodeAt(0);
  if (l === 'ru' && ((code >= 1072 && code <= 1103) || code === 1105)) return String(code); // а-я, ё
  if (l === 'en' && code >= 97 && code <= 122) return String(code); // a-z
  return null; // символы/чужой алфавит для текущего языка — озвучки нет
}

/** Проговорить символ (буква/цифра) на текущем языке интерфейса, если озвучка включена. Тихо игнорит остальное. */
export function speak(ch: string): void {
  if (!voiceOn) return;
  const f = fileFor(ch);
  if (!f) return;
  const l = lang();
  const key = `${l}/${f}`;
  let a = cache.get(key);
  if (!a) { a = new Audio(`audio/${l}/${f}.ogg`); a.preload = 'auto'; cache.set(key, a); }
  try { a.currentTime = 0; void a.play(); } catch { /* автоплей/формат — молча */ }
}

/** Есть ли вообще что озвучивать для этого символа на текущем языке (для UI-подсказок). */
export function canSpeak(ch: string): boolean { return fileFor(ch) !== null; }
