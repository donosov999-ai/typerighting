// Интерфейс на двух языках (RU/EN) — заказ Дениса 12.06.2026 под
// англоязычный рынок (индийские школьники). Язык хранится в tr_lang,
// по умолчанию RU (родной рынок), на онбординге — переключатель.
export type Lang = 'ru' | 'en';

let current: Lang = (() => {
  const v = localStorage.getItem('tr_lang');
  return v === 'en' ? 'en' : 'ru';
})();

export function lang(): Lang { return current; }
export function setLang(l: Lang) {
  current = l;
  try { localStorage.setItem('tr_lang', l); } catch { /* quota */ }
}

const DICT: Record<string, { ru: string; en: string }> = {
  // онбординг
  'ob.sub': { ru: 'Тренажёр слепой печати. Для кого настроить?', en: 'Touch typing trainer. Who is it for?' },
  'ob.note': { ru: 'Профиль можно сменить в любой момент в шапке.', en: 'You can switch the profile any time in the header.' },
  'profile.m': { ru: 'Мужской', en: 'Classic' },
  'profile.f': { ru: 'Женский', en: 'Soft' },
  'profile.kids': { ru: 'Детский', en: 'Kids' },
  'profile.m.desc': { ru: 'Светлая тема, скорость и рекорды', en: 'Light theme, speed and records' },
  'profile.f.desc': { ru: 'Светлая тёплая тема, мягкий темп', en: 'Warm light theme, gentle pace' },
  'profile.kids.desc': { ru: 'Игра: уровни, звёзды и котик', en: 'Game: levels, stars and a cat' },
  // банки
  'bank.abandon': { ru: 'Слова в предложениях', en: 'Words in sentences' },
  'bank.engRus': { ru: 'Англ↔Рус (с переводом)', en: 'EN words + RU hints' },
  'bank.letterByLetter': { ru: 'По буквам (наращивание)', en: 'Letter by letter' },
  'bank.poemHymn': { ru: 'Стихи и гимны', en: 'Poems & hymns' },
  'bank.abandon.desc': { ru: 'Печатай предложение с новым словом — словарный запас + скорость.', en: 'Type a sentence with a new word — vocabulary + speed.' },
  'bank.engRus.desc': { ru: 'Слово с переводом + предложение. Перевод-подсказка над образцом.', en: 'A word with RU translation + a sentence to type.' },
  'bank.letterByLetter.desc': { ru: 'Слово печатается по нарастающей: a, ab, aba… — постановка пальцев.', en: 'Build the word up: a, ab, aba… — finger placement.' },
  'bank.poemHymn.desc': { ru: 'Стихи и гимны по строфам (4–8 строк) — ритм и выносливость печати.', en: 'Poems & hymns by stanza (4–8 lines) — rhythm and stamina.' },
  // тулбар
  'tb.hide': { ru: 'Спрятать образец', en: 'Hide pattern' },
  'tb.sound': { ru: 'Звук ошибки', en: 'Error sound' },
  'tb.block': { ru: 'Блок при ошибке', en: 'Block on error' },
  'tb.keyb': { ru: 'Клавиатура', en: 'Keyboard' },
  'tb.flow': { ru: 'Поток', en: 'Flow' },
  'tb.heat': { ru: 'Тепловая карта', en: 'Heatmap' },
  'tb.exam': { ru: 'Тест', en: 'Test' },
  'tb.weak': { ru: '🎯 Слабые клавиши', en: '🎯 Weak keys' },
  'tb.custom': { ru: '✎ Свой текст', en: '✎ Custom text' },
  'tb.progress': { ru: '📈 Прогресс', en: '📈 Progress' },
  'tb.course': { ru: '📚 Курс', en: '📚 Course' },
  'tb.learn': { ru: '🤖 AI-обучение', en: '🤖 AI training' },
  // AI-режим
  'learn.title': { ru: 'AI-обучение', en: 'AI training' },
  'learn.intro': { ru: 'Программа сама генерирует связные строки и подмешивает буквы, где ты ошибаешься. Просто печатай поток — она подстраивается.', en: 'The program generates connected lines and mixes in the letters you miss. Just type the stream — it adapts to you.' },
  'learn.intro.kids': { ru: 'Печатай слова, которые придумывает котик! Чем точнее — тем лучше 🐱', en: 'Type the words the cat makes up! The more accurate, the better 🐱' },
  'learn.mastery': { ru: 'Мастерство', en: 'Mastery' },
  'learn.tempo': { ru: 'Темп', en: 'Tempo' },
  'learn.rhythm': { ru: 'Ритмичность', en: 'Rhythm' },
  'learn.lines': { ru: 'строк', en: 'lines' },
  'learn.tip': { ru: 'Мастерство — скорость с учётом ошибок (сим/мин). Ритмичность >80% — ровный темп профи.', en: 'Mastery — speed adjusted for errors (chars/min). Rhythm >80% — pro-level evenness.' },
  'learn.lvl.start': { ru: 'старт', en: 'start' },
  'learn.lvl.good': { ru: 'хорошо', en: 'good' },
  'learn.lvl.work': { ru: 'рабочий', en: 'working' },
  'learn.lvl.pro': { ru: 'профи', en: 'pro' },
  // структурированный курс
  'course.title': { ru: 'Курс печати', en: 'Typing course' },
  'course.intro': { ru: 'Последовательные уроки от домашнего ряда до предложений. Каждый урок открывает следующий.', en: 'Step-by-step lessons from the home row to sentences. Each lesson unlocks the next.' },
  'course.exit': { ru: '⚙ Выход', en: '⚙ Exit' },
  'course.lesson': { ru: 'Урок', en: 'Lesson' },
  'course.line': { ru: 'строка', en: 'line' },
  'course.tip': { ru: 'Печатай ровно и точно — скорость придёт сама.', en: 'Type evenly and accurately — speed will follow.' },
  'course.home': { ru: 'Домашний ряд', en: 'Home row' },
  'course.review': { ru: 'Повторение домашнего ряда', en: 'Home row review' },
  'course.keys': { ru: 'Новые клавиши', en: 'New keys' },
  'course.caps': { ru: 'Заглавные буквы (Shift)', en: 'Capitals (Shift)' },
  'course.digits': { ru: 'Цифры', en: 'Numbers' },
  'course.punct': { ru: 'Знаки препинания', en: 'Punctuation' },
  'course.words': { ru: 'Частые слова', en: 'Common words' },
  'course.sentences': { ru: 'Предложения', en: 'Sentences' },
  'tb.dark': { ru: 'Тёмная тема', en: 'Dark theme' },
  'tb.prev': { ru: '‹ Пред', en: '‹ Prev' },
  'tb.next': { ru: 'След ›', en: 'Next ›' },
  // адаптив / прогресс / свой текст
  'weak.title': { ru: 'Слабые клавиши', en: 'Weak keys' },
  'weak.hint': { ru: 'Упражнение собрано из клавиш, где у тебя больше всего ошибок. «След» — новый набор.', en: 'Built from the keys you miss most. “Next” — a fresh set.' },
  'weak.none': { ru: 'Пока мало данных — тренируем домашний ряд. Печатай ещё, и появятся твои слабые клавиши.', en: 'Not enough data yet — training the home row. Keep typing to reveal your weak keys.' },
  'prog.title': { ru: 'Прогресс по сессиям', en: 'Progress by session' },
  'prog.empty': { ru: 'Недостаточно данных. Пройди хотя бы 2 упражнения — появится график скорости.', en: 'Not enough data. Finish at least 2 exercises to see the speed chart.' },
  'prog.close': { ru: 'Закрыть', en: 'Close' },
  'custom.title': { ru: 'Свой текст', en: 'Custom text' },
  'custom.ph': { ru: 'Вставь любой текст для тренировки…', en: 'Paste any text to practice…' },
  'custom.start': { ru: 'Тренировать', en: 'Practice' },
  'custom.cancel': { ru: 'Отмена', en: 'Cancel' },
  // статистика
  'st.exercises': { ru: 'упражнений', en: 'exercises' },
  'st.done': { ru: 'пройдено', en: 'done' },
  'st.record': { ru: 'рекорд', en: 'best' },
  'st.wpm': { ru: 'WPM', en: 'WPM' }, // стандартная метрика (chars/5 в минуту)
  'st.accuracy': { ru: 'точность', en: 'accuracy' },
  'st.errors': { ru: 'ошибок', en: 'errors' },
  'st.time': { ru: 'время', en: 'time' },
  'st.streak': { ru: 'подряд', en: 'streak' },
  // подсказки и done
  'hint.flow': { ru: 'Поток: упражнения идут подряд без остановки.', en: 'Flow: exercises run back to back, no stops.' },
  'hint.type': { ru: 'Печатай по образцу.', en: 'Type the pattern.' },
  'hint.block': { ru: 'Неверный символ не пропускается.', en: 'Wrong keys are not accepted.' },
  'hint.bs': { ru: 'Backspace — исправить.', en: 'Backspace to fix.' },
  'hint.hidden': { ru: 'образец скрыт — печатай по памяти', en: 'pattern hidden — type from memory' },
  'done.title': { ru: '✓ Готово', en: '✓ Done' },
  'done.title.f': { ru: '✓ Отлично!', en: '✓ Great job!' },
  'done.again': { ru: '↻ Заново', en: '↻ Again' },
  'done.next': { ru: 'Следующее →', en: 'Next →' },
  'err.load': { ru: 'Не удалось загрузить упражнения', en: 'Failed to load exercises' },
  // детский режим
  'k.title': { ru: '🐱 Котик-печатник', en: '🐱 Typing Cat' },
  'k.hello': { ru: 'Привет! Выбирай уровень — будем учиться печатать. Печатай точно, спешить не надо!', en: 'Hi! Pick a level and let’s learn to type. Be accurate — no need to rush!' },
  'k.rest': { ru: '🐱 Ты отлично позанимался! Передохни немножко 💛', en: '🐱 Great practice! Take a little break 💛' },
  'k.block.ru': { ru: '🇷🇺 По-русски', en: '🇷🇺 Russian' },
  'k.block.en': { ru: '🇬🇧 По-английски', en: '🇬🇧 English' },
  'k.level': { ru: 'Уровень', en: 'Level' },
  'k.word': { ru: 'слово', en: 'word' },
  'k.noerr': { ru: '⭐ без ошибок', en: '⭐ no errors' },
  'k.errors': { ru: 'ошибок', en: 'errors' },
  'k.passed': { ru: 'пройден!', en: 'passed!' },
  'k.note3': { ru: 'Ни одной ошибки — ты звезда!', en: 'Not a single error — you are a star!' },
  'k.note2': { ru: 'Очень здорово! Ещё чуть точнее — будет три звезды.', en: 'Very good! A bit more accurate for three stars.' },
  'k.note1': { ru: 'Уровень пройден! Попробуй ещё раз — получится точнее.', en: 'Level passed! Try again to be more accurate.' },
  'k.again': { ru: '↻ Ещё раз', en: '↻ Again' },
  'k.map': { ru: 'К карте', en: 'To map' },
  'k.next': { ru: 'Дальше →', en: 'Next →' },
  'k.back': { ru: '← К карте', en: '← To map' },
  'k.startRu': { ru: 'Печатаем по-русски!', en: 'Typing in Russian!' },
  'k.startEn': { ru: 'Печатаем по-английски!', en: 'Typing in English!' },
  // экзамен
  'ex.title': { ru: 'Тест печати', en: 'Typing Test' },
  'ex.desc': { ru: 'Печатай предложения без остановки, пока не выйдет время. В конце — отчёт с Gross/Net WPM и точностью.', en: 'Type sentences non-stop until the time runs out. You get a report with Gross/Net WPM and accuracy.' },
  'ex.duration': { ru: 'Длительность', en: 'Duration' },
  'ex.min': { ru: 'мин', en: 'min' },
  'ex.target': { ru: 'Цель Net WPM', en: 'Target Net WPM' },
  'ex.name': { ru: 'Имя (для сертификата)', en: 'Name (for the certificate)' },
  'ex.start': { ru: 'Начать тест', en: 'Start test' },
  'ex.cancel': { ru: 'Выйти', en: 'Exit' },
  'ex.left': { ru: 'осталось', en: 'left' },
  'ex.result': { ru: 'Результат теста', en: 'Test result' },
  'ex.gross': { ru: 'Gross WPM', en: 'Gross WPM' },
  'ex.net': { ru: 'Net WPM', en: 'Net WPM' },
  'ex.keystrokes': { ru: 'нажатий', en: 'keystrokes' },
  'ex.pass': { ru: 'СДАН', en: 'PASS' },
  'ex.fail': { ru: 'НЕ СДАН', en: 'FAIL' },
  'ex.target.short': { ru: 'цель', en: 'target' },
  'ex.cert': { ru: '⬇ Сертификат (PNG)', en: '⬇ Certificate (PNG)' },
  'ex.again': { ru: '↻ Ещё раз', en: '↻ Try again' },
  'ex.cert.title': { ru: 'СЕРТИФИКАТ', en: 'CERTIFICATE' },
  'ex.cert.sub': { ru: 'тест слепой печати', en: 'touch typing test' },
  'ex.cert.date': { ru: 'Дата', en: 'Date' },
};

export function t(key: string): string {
  const e = DICT[key];
  if (!e) return key;
  return e[current];
}
