// F1 озвучка: проговаривание букв/цифр при вводе. Аудио — офлайн-семплы Silero TTS
// (голос xenia, RU), предгенерированы на Contabo-FR, лежат в public/audio/ru/.
// Имя файла: русская буква = её Unicode-код (а=1072..я=1103, ё=1105), цифра = 'd'+цифра.
// Пока только RU (Silero v4_ru); EN — follow-up (нужна модель v3_en).

let voiceOn = false;
try { voiceOn = localStorage.getItem('tr_voice') === '1'; } catch { /* */ }

export function setVoiceEnabled(on: boolean) {
  voiceOn = on;
  try { localStorage.setItem('tr_voice', on ? '1' : '0'); } catch { /* */ }
}
export function voiceEnabled(): boolean { return voiceOn; }

const cache = new Map<string, HTMLAudioElement>();

function fileFor(ch: string): string | null {
  if (!ch) return null;
  if (ch >= '0' && ch <= '9') return 'd' + ch;
  const code = ch.toLowerCase().charCodeAt(0);
  if ((code >= 1072 && code <= 1103) || code === 1105) return String(code); // а-я, ё
  return null; // латиница/символы — озвучки нет
}

/** Проговорить символ (буква/цифра), если озвучка включена. Тихо игнорит остальное. */
export function speak(ch: string): void {
  if (!voiceOn) return;
  const f = fileFor(ch);
  if (!f) return;
  let a = cache.get(f);
  if (!a) { a = new Audio(`audio/ru/${f}.ogg`); a.preload = 'auto'; cache.set(f, a); }
  try { a.currentTime = 0; void a.play(); } catch { /* автоплей/формат — молча */ }
}

/** Есть ли вообще что озвучивать для этого символа (для UI-подсказок). */
export function canSpeak(ch: string): boolean { return fileFor(ch) !== null; }
