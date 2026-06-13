// Интерфейс на 7 языках (заказ Дениса 13.06.2026). Язык в tr_lang, дефолт RU.
// ru/en обязательны; es/de/fr/it/pt опциональны с fallback на en (t() ниже).
export type Lang = 'ru' | 'en' | 'es' | 'de' | 'fr' | 'it' | 'pt';
export const LANGS: Lang[] = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
export const LANG_LABEL: Record<Lang, string> = { ru: '🇷🇺 RU', en: '🇬🇧 EN', es: '🇪🇸 ES', de: '🇩🇪 DE', fr: '🇫🇷 FR', it: '🇮🇹 IT', pt: '🇵🇹 PT' };

let current: Lang = (() => {
  const v = localStorage.getItem('tr_lang');
  if ((LANGS as string[]).includes(v ?? '')) return v as Lang; // явный выбор пользователя
  // автоопределение по языку системы (первый запуск)
  const sys = ((typeof navigator !== 'undefined' && (navigator.language || (navigator.languages && navigator.languages[0]))) || 'en').slice(0, 2).toLowerCase();
  return (LANGS as string[]).includes(sys) ? (sys as Lang) : 'en';
})();

export function lang(): Lang { return current; }
export function setLang(l: Lang) {
  current = l;
  try { localStorage.setItem('tr_lang', l); } catch { /* quota */ }
}

type Entry = { ru: string; en: string; es?: string; de?: string; fr?: string; it?: string; pt?: string };
const DICT: Record<string, Entry> = {
  // онбординг
  'ob.sub': { ru: 'Тренажёр слепой печати. Для кого настроить?', en: 'Touch typing trainer. Who is it for?', es: 'Mecanografía al tacto. ¿Para quién es?', de: 'Tipptrainer. Für wen ist es?', fr: 'Dactylographie. Pour qui ?', it: 'Dattilografia. Per chi è?', pt: 'Treino de digitação. Para quem é?' },
  'ob.note': { ru: 'Профиль можно сменить в любой момент в шапке.', en: 'You can switch the profile any time in the header.', es: 'Puedes cambiar el perfil en cualquier momento arriba.', de: 'Profil jederzeit oben umschaltbar.', fr: 'Le profil est modifiable à tout moment en haut.', it: 'Puoi cambiare profilo in qualsiasi momento in alto.', pt: 'Pode trocar o perfil a qualquer momento no topo.' },
  'profile.m': { ru: 'Мужской', en: 'Classic', es: 'Clásico', de: 'Klassisch', fr: 'Classique', it: 'Classico', pt: 'Clássico' },
  'profile.f': { ru: 'Женский', en: 'Soft', es: 'Suave', de: 'Sanft', fr: 'Doux', it: 'Morbido', pt: 'Suave' },
  'profile.kids': { ru: 'Детский', en: 'Kids', es: 'Niños', de: 'Kinder', fr: 'Enfants', it: 'Bambini', pt: 'Crianças' },
  'profile.m.desc': { ru: 'Светлая тема, скорость и рекорды', en: 'Light theme, speed and records', es: 'Tema claro, velocidad y récords', de: 'Helles Thema, Tempo und Rekorde', fr: 'Thème clair, vitesse et records', it: 'Tema chiaro, velocità e record', pt: 'Tema claro, velocidade e recordes' },
  'profile.f.desc': { ru: 'Светлая тёплая тема, мягкий темп', en: 'Warm light theme, gentle pace', es: 'Tema claro cálido, ritmo suave', de: 'Warmes helles Thema, sanftes Tempo', fr: 'Thème clair chaud, rythme doux', it: 'Tema chiaro caldo, ritmo dolce', pt: 'Tema claro quente, ritmo suave' },
  'profile.kids.desc': { ru: 'Игра: уровни, звёзды и котик', en: 'Game: levels, stars and a cat', es: 'Juego: niveles, estrellas y un gato', de: 'Spiel: Level, Sterne und Katze', fr: 'Jeu : niveaux, étoiles et un chat', it: 'Gioco: livelli, stelle e un gatto', pt: 'Jogo: níveis, estrelas e um gato' },
  // банки
  'bank.abandon': { ru: 'Слова в предложениях', en: 'Words in sentences', es: 'Palabras en frases', de: 'Wörter in Sätzen', fr: 'Mots dans des phrases', it: 'Parole in frasi', pt: 'Palavras em frases' },
  'bank.engRus': { ru: 'Англ↔Рус (с переводом)', en: 'EN words + RU hints', es: 'Palabras EN + pistas RU', de: 'EN-Wörter + RU-Hinweise', fr: 'Mots EN + indices RU', it: 'Parole EN + suggerimenti RU', pt: 'Palavras EN + dicas RU' },
  'bank.letterByLetter': { ru: 'По буквам (наращивание)', en: 'Letter by letter', es: 'Letra por letra', de: 'Buchstabe für Buchstabe', fr: 'Lettre par lettre', it: 'Lettera per lettera', pt: 'Letra por letra' },
  'bank.poemHymn': { ru: 'Стихи: «Ворон»', en: 'Poetry: The Raven', es: 'Poesía: El cuervo', de: 'Poesie: Der Rabe', fr: 'Poésie : Le Corbeau', it: 'Poesia: Il corvo', pt: 'Poesia: O Corvo' },
  'bank.abandon.desc': { ru: 'Печатай предложение с новым словом — словарный запас + скорость.', en: 'Type a sentence with a new word — vocabulary + speed.', es: 'Escribe una frase con una palabra nueva — vocabulario + velocidad.', de: 'Tippe einen Satz mit einem neuen Wort — Wortschatz + Tempo.', fr: 'Tapez une phrase avec un nouveau mot — vocabulaire + vitesse.', it: 'Digita una frase con una parola nuova — vocabolario + velocità.', pt: 'Digite uma frase com uma palavra nova — vocabulário + velocidade.' },
  'bank.engRus.desc': { ru: 'Слово с переводом + предложение. Перевод-подсказка над образцом.', en: 'A word with RU translation + a sentence to type.', es: 'Una palabra con traducción RU + una frase.', de: 'Ein Wort mit RU-Übersetzung + ein Satz.', fr: 'Un mot avec traduction RU + une phrase.', it: 'Una parola con traduzione RU + una frase.', pt: 'Uma palavra com tradução RU + uma frase.' },
  'bank.letterByLetter.desc': { ru: 'Слово печатается по нарастающей: a, ab, aba… — постановка пальцев.', en: 'Build the word up: a, ab, aba… — finger placement.', es: 'Construye la palabra: a, ab, aba… — colocación de dedos.', de: 'Wort aufbauen: a, ab, aba… — Fingerhaltung.', fr: 'Construire le mot : a, ab, aba… — placement des doigts.', it: 'Costruisci la parola: a, ab, aba… — posizione delle dita.', pt: 'Construa a palavra: a, ab, aba… — posição dos dedos.' },
  'bank.poemHymn.desc': { ru: '«Ворон» Эдгара По на вашем языке, по строфам — ритм и выносливость печати.', en: 'Poe’s “The Raven” in your language, by stanza — rhythm and stamina.', es: '“El cuervo” de Poe en tu idioma, por estrofa — ritmo y resistencia.', de: 'Poes „Der Rabe“ in Ihrer Sprache, je Strophe — Rhythmus und Ausdauer.', fr: '« Le Corbeau » de Poe dans votre langue, par strophe — rythme et endurance.', it: '“Il corvo” di Poe nella tua lingua, per strofa — ritmo e resistenza.', pt: '“O Corvo” de Poe no seu idioma, por estrofe — ritmo e resistência.' },
  // тулбар
  'tb.hide': { ru: 'Спрятать образец', en: 'Hide pattern', es: 'Ocultar modelo', de: 'Vorlage verbergen', fr: 'Masquer le modèle', it: 'Nascondi modello', pt: 'Ocultar modelo' },
  'tb.sound': { ru: 'Звук ошибки', en: 'Error sound', es: 'Sonido de error', de: 'Fehlerton', fr: 'Son d’erreur', it: 'Suono errore', pt: 'Som de erro' },
  'tb.block': { ru: 'Блок при ошибке', en: 'Block on error', es: 'Bloquear si hay error', de: 'Bei Fehler blockieren', fr: 'Bloquer si erreur', it: 'Blocca se errore', pt: 'Bloquear no erro' },
  'tb.keyb': { ru: 'Клавиатура', en: 'Keyboard', es: 'Teclado', de: 'Tastatur', fr: 'Clavier', it: 'Tastiera', pt: 'Teclado' },
  'tb.flow': { ru: 'Поток', en: 'Flow', es: 'Flujo', de: 'Fluss', fr: 'Flux', it: 'Flusso', pt: 'Fluxo' },
  'tb.heat': { ru: 'Тепловая карта', en: 'Heatmap', es: 'Mapa de calor', de: 'Heatmap', fr: 'Carte de chaleur', it: 'Mappa di calore', pt: 'Mapa de calor' },
  'tb.exam': { ru: 'Тест', en: 'Test', es: 'Prueba', de: 'Test', fr: 'Test', it: 'Test', pt: 'Teste' },
  'tb.weak': { ru: '🎯 Слабые клавиши', en: '🎯 Weak keys', es: '🎯 Teclas débiles', de: '🎯 Schwache Tasten', fr: '🎯 Touches faibles', it: '🎯 Tasti deboli', pt: '🎯 Teclas fracas' },
  'tb.custom': { ru: '✎ Свой текст', en: '✎ Custom text', es: '✎ Texto propio', de: '✎ Eigener Text', fr: '✎ Texte perso', it: '✎ Testo tuo', pt: '✎ Texto próprio' },
  'tb.progress': { ru: '📈 Прогресс', en: '📈 Progress', es: '📈 Progreso', de: '📈 Fortschritt', fr: '📈 Progrès', it: '📈 Progresso', pt: '📈 Progresso' },
  'tb.course': { ru: '📚 Курс', en: '📚 Course', es: '📚 Curso', de: '📚 Kurs', fr: '📚 Cours', it: '📚 Corso', pt: '📚 Curso' },
  'tb.learn': { ru: '🤖 AI-обучение', en: '🤖 AI training', es: '🤖 IA', de: '🤖 KI-Training', fr: '🤖 IA', it: '🤖 IA', pt: '🤖 IA' },
  'tb.compete': { ru: '🏆 Соревнование', en: '🏆 Compete', es: '🏆 Competir', de: '🏆 Wettkampf', fr: '🏆 Compétition', it: '🏆 Gara', pt: '🏆 Competir' },
  // хаб
  'hub.q': { ru: 'С чего начнём?', en: 'Where to start?', es: '¿Por dónde empezar?', de: 'Womit beginnen?', fr: 'Par où commencer ?', it: 'Da dove iniziare?', pt: 'Por onde começar?' },
  'hub.home': { ru: 'Главная', en: 'Home', es: 'Inicio', de: 'Start', fr: 'Accueil', it: 'Home', pt: 'Início' },
  'hub.settings': { ru: 'Настройки', en: 'Settings', es: 'Ajustes', de: 'Einstellungen', fr: 'Réglages', it: 'Impostazioni', pt: 'Definições' },
  'hub.train': { ru: 'Тренировка', en: 'Practice', es: 'Práctica', de: 'Übung', fr: 'Entraînement', it: 'Allenamento', pt: 'Prática' },
  'hub.train.d': { ru: 'Упражнения по банкам: слова, тексты, стихи', en: 'Exercise banks: words, texts, poems', es: 'Bancos de ejercicios: palabras, textos, poemas', de: 'Übungsbänke: Wörter, Texte, Gedichte', fr: 'Banques d’exercices : mots, textes, poèmes', it: 'Banche di esercizi: parole, testi, poesie', pt: 'Bancos de exercícios: palavras, textos, poemas' },
  'hub.course.d': { ru: 'Уроки с нуля до текста, по шагам', en: 'Lessons from scratch to text, step by step', es: 'Lecciones desde cero hasta el texto, paso a paso', de: 'Lektionen von Grund auf bis zum Text', fr: 'Leçons de zéro au texte, étape par étape', it: 'Lezioni da zero al testo, passo dopo passo', pt: 'Lições do zero ao texto, passo a passo' },
  'hub.learn.d': { ru: 'Умный поток, подстраивается под ошибки', en: 'Smart stream, adapts to your mistakes', es: 'Flujo inteligente, se adapta a tus errores', de: 'Smarter Strom, passt sich Fehlern an', fr: 'Flux intelligent, s’adapte aux erreurs', it: 'Flusso smart, si adatta agli errori', pt: 'Fluxo inteligente, adapta-se aos erros' },
  'hub.compete.d': { ru: 'Дисциплины на скорость + онлайн-таблица', en: 'Speed disciplines + online board', es: 'Disciplinas de velocidad + tabla en línea', de: 'Speed-Disziplinen + Online-Tabelle', fr: 'Disciplines de vitesse + classement en ligne', it: 'Discipline di velocità + classifica online', pt: 'Disciplinas de velocidade + tabela online' },
  'hub.exam.d': { ru: 'Тест на время с сертификатом', en: 'Timed test with a certificate', es: 'Prueba cronometrada con certificado', de: 'Test auf Zeit mit Zertifikat', fr: 'Test chronométré avec certificat', it: 'Test a tempo con certificato', pt: 'Teste cronometrado com certificado' },
  'hub.progress.d': { ru: 'График скорости и рекорды', en: 'Speed chart and records', es: 'Gráfico de velocidad y récords', de: 'Tempo-Diagramm und Rekorde', fr: 'Graphique de vitesse et records', it: 'Grafico velocità e record', pt: 'Gráfico de velocidade e recordes' },
  'hub.streak': { ru: 'дней подряд', en: 'day streak', es: 'días seguidos', de: 'Tage am Stück', fr: 'jours d’affilée', it: 'giorni di fila', pt: 'dias seguidos' },
  'nav.back': { ru: '← Назад', en: '← Back', es: '← Atrás', de: '← Zurück', fr: '← Retour', it: '← Indietro', pt: '← Voltar' },
  'nav.tomap': { ru: '← К списку', en: '← To list', es: '← A la lista', de: '← Zur Liste', fr: '← À la liste', it: '← All’elenco', pt: '← À lista' },
  // соревнование
  'compete.title': { ru: 'Тест-соревнование', en: 'Typing Compete', es: 'Competición', de: 'Wettkampf', fr: 'Compétition', it: 'Gara', pt: 'Competição' },
  'compete.intro': { ru: 'Выбери дисциплину и поставь рекорд. Результат можно опубликовать в онлайн-таблице.', en: 'Pick a discipline and set a record. Publish your result to the online leaderboard.', es: 'Elige una disciplina y marca un récord. Publica tu resultado en la tabla en línea.', de: 'Wähle eine Disziplin und stelle einen Rekord auf. Veröffentliche dein Ergebnis online.', fr: 'Choisis une discipline et bats un record. Publie ton résultat dans le classement en ligne.', it: 'Scegli una disciplina e fai un record. Pubblica il risultato nella classifica online.', pt: 'Escolhe uma disciplina e bate um recorde. Publica o resultado na tabela online.' },
  'comp.alpha_fwd': { ru: 'Алфавит А→Я', en: 'Alphabet A→Z', es: 'Alfabeto A→Z', de: 'Alphabet A→Z', fr: 'Alphabet A→Z', it: 'Alfabeto A→Z', pt: 'Alfabeto A→Z' },
  'comp.alpha_rev': { ru: 'Алфавит Я→А', en: 'Alphabet Z→A', es: 'Alfabeto Z→A', de: 'Alphabet Z→A', fr: 'Alphabet Z→A', it: 'Alfabeto Z→A', pt: 'Alfabeto Z→A' },
  'comp.words': { ru: 'Слова', en: 'Words', es: 'Palabras', de: 'Wörter', fr: 'Mots', it: 'Parole', pt: 'Palavras' },
  'comp.digits': { ru: 'Цифры', en: 'Numbers', es: 'Números', de: 'Zahlen', fr: 'Chiffres', it: 'Numeri', pt: 'Números' },
  'comp.sprint': { ru: 'Спринт', en: 'Sprint', es: 'Sprint', de: 'Sprint', fr: 'Sprint', it: 'Sprint', pt: 'Sprint' },
  'comp.best': { ru: 'рекорд', en: 'best', es: 'récord', de: 'Rekord', fr: 'record', it: 'record', pt: 'recorde' },
  'comp.hint': { ru: 'на скорость, без ошибок', en: 'for speed, no errors', es: 'por velocidad, sin errores', de: 'auf Tempo, ohne Fehler', fr: 'pour la vitesse, sans fautes', it: 'a velocità, senza errori', pt: 'por velocidade, sem erros' },
  'comp.record': { ru: 'Новый личный рекорд!', en: 'New personal record!', es: '¡Nuevo récord personal!', de: 'Neuer persönlicher Rekord!', fr: 'Nouveau record personnel !', it: 'Nuovo record personale!', pt: 'Novo recorde pessoal!' },
  'comp.name': { ru: 'Имя для таблицы', en: 'Name for the board', es: 'Nombre para la tabla', de: 'Name für die Tabelle', fr: 'Nom pour le classement', it: 'Nome per la classifica', pt: 'Nome para a tabela' },
  'comp.publish': { ru: 'Опубликовать', en: 'Publish', es: 'Publicar', de: 'Veröffentlichen', fr: 'Publier', it: 'Pubblica', pt: 'Publicar' },
  'comp.leaderboard': { ru: 'Таблица рекордов', en: 'Leaderboard', es: 'Clasificación', de: 'Bestenliste', fr: 'Classement', it: 'Classifica', pt: 'Classificação' },
  'comp.player': { ru: 'Игрок', en: 'Player', es: 'Jugador', de: 'Spieler', fr: 'Joueur', it: 'Giocatore', pt: 'Jogador' },
  'comp.loading': { ru: 'Загрузка таблицы…', en: 'Loading board…', es: 'Cargando tabla…', de: 'Tabelle lädt…', fr: 'Chargement…', it: 'Caricamento…', pt: 'A carregar…' },
  'comp.empty': { ru: 'Пока нет результатов — будь первым!', en: 'No results yet — be the first!', es: 'Sin resultados aún — ¡sé el primero!', de: 'Noch keine Ergebnisse — sei der Erste!', fr: 'Pas encore de résultats — sois le premier !', it: 'Ancora nessun risultato — sii il primo!', pt: 'Ainda sem resultados — sê o primeiro!' },
  // AI-режим
  'learn.title': { ru: 'AI-обучение', en: 'AI training', es: 'Entrenamiento IA', de: 'KI-Training', fr: 'Entraînement IA', it: 'Allenamento IA', pt: 'Treino IA' },
  'learn.intro': { ru: 'Программа сама генерирует связные строки и подмешивает буквы, где ты ошибаешься. Просто печатай поток — она подстраивается.', en: 'The program generates connected lines and mixes in the letters you miss. Just type the stream — it adapts to you.', es: 'El programa genera líneas con sentido y añade las letras que fallas. Solo escribe — se adapta a ti.', de: 'Das Programm erzeugt zusammenhängende Zeilen und mischt deine Fehlerbuchstaben ein. Tippe einfach — es passt sich an.', fr: 'Le programme génère des lignes cohérentes et ajoute les lettres ratées. Tape simplement — il s’adapte.', it: 'Il programma genera righe coerenti e aggiunge le lettere che sbagli. Scrivi e basta — si adatta.', pt: 'O programa gera linhas com sentido e mistura as letras que erras. Escreve — ele adapta-se.' },
  'learn.intro.kids': { ru: 'Печатай слова, которые придумывает котик! Чем точнее — тем лучше 🐱', en: 'Type the words the cat makes up! The more accurate, the better 🐱', es: '¡Escribe las palabras del gato! Cuanto más preciso, mejor 🐱', de: 'Tippe die Wörter der Katze! Je genauer, desto besser 🐱', fr: 'Tape les mots du chat ! Plus c’est précis, mieux c’est 🐱', it: 'Digita le parole del gatto! Più preciso, meglio è 🐱', pt: 'Digita as palavras do gato! Quanto mais preciso, melhor 🐱' },
  'learn.mastery': { ru: 'Мастерство', en: 'Mastery', es: 'Maestría', de: 'Können', fr: 'Maîtrise', it: 'Maestria', pt: 'Mestria' },
  'learn.tempo': { ru: 'Темп', en: 'Tempo', es: 'Ritmo', de: 'Tempo', fr: 'Tempo', it: 'Tempo', pt: 'Ritmo' },
  'learn.rhythm': { ru: 'Ритмичность', en: 'Rhythm', es: 'Cadencia', de: 'Rhythmus', fr: 'Régularité', it: 'Ritmo', pt: 'Cadência' },
  'learn.lines': { ru: 'строк', en: 'lines', es: 'líneas', de: 'Zeilen', fr: 'lignes', it: 'righe', pt: 'linhas' },
  'learn.tip': { ru: 'Мастерство — скорость с учётом ошибок (сим/мин). Ритмичность >80% — ровный темп профи.', en: 'Mastery — speed adjusted for errors (chars/min). Rhythm >80% — pro-level evenness.', es: 'Maestría — velocidad ajustada por errores (car/min). Cadencia >80% — nivel profesional.', de: 'Können — Tempo abzüglich Fehler (Z/min). Rhythmus >80% — Profi-Niveau.', fr: 'Maîtrise — vitesse ajustée des erreurs (car/min). Régularité >80 % — niveau pro.', it: 'Maestria — velocità al netto degli errori (car/min). Ritmo >80% — livello pro.', pt: 'Mestria — velocidade ajustada por erros (car/min). Cadência >80% — nível pro.' },
  'learn.lvl.start': { ru: 'старт', en: 'start', es: 'inicio', de: 'Start', fr: 'début', it: 'inizio', pt: 'início' },
  'learn.lvl.good': { ru: 'хорошо', en: 'good', es: 'bien', de: 'gut', fr: 'bien', it: 'bene', pt: 'bom' },
  'learn.lvl.work': { ru: 'рабочий', en: 'working', es: 'funcional', de: 'solide', fr: 'opérationnel', it: 'buono', pt: 'funcional' },
  'learn.lvl.pro': { ru: 'профи', en: 'pro', es: 'pro', de: 'Profi', fr: 'pro', it: 'pro', pt: 'pro' },
  'learn.hand': { ru: 'Рука', en: 'Hand', es: 'Mano', de: 'Hand', fr: 'Main', it: 'Mano', pt: 'Mão' },
  'learn.hand.both': { ru: 'Обе', en: 'Both', es: 'Ambas', de: 'Beide', fr: 'Deux', it: 'Entrambe', pt: 'Ambas' },
  'learn.hand.left': { ru: 'Левая', en: 'Left', es: 'Izquierda', de: 'Links', fr: 'Gauche', it: 'Sinistra', pt: 'Esquerda' },
  'learn.hand.right': { ru: 'Правая', en: 'Right', es: 'Derecha', de: 'Rechts', fr: 'Droite', it: 'Destra', pt: 'Direita' },
  // курс
  'course.title': { ru: 'Курс печати', en: 'Typing course', es: 'Curso de mecanografía', de: 'Tippkurs', fr: 'Cours de dactylo', it: 'Corso di dattilografia', pt: 'Curso de digitação' },
  'course.intro': { ru: 'Последовательные уроки от домашнего ряда до предложений. Каждый урок открывает следующий.', en: 'Step-by-step lessons from the home row to sentences. Each lesson unlocks the next.', es: 'Lecciones paso a paso desde la fila base hasta frases. Cada una abre la siguiente.', de: 'Schritt-für-Schritt von der Grundreihe bis zu Sätzen. Jede Lektion schaltet die nächste frei.', fr: 'Leçons progressives de la rangée de repos aux phrases. Chacune débloque la suivante.', it: 'Lezioni passo passo dalla fila base alle frasi. Ognuna sblocca la successiva.', pt: 'Lições passo a passo da fila base às frases. Cada uma abre a seguinte.' },
  'course.exit': { ru: '⚙ Выход', en: '⚙ Exit', es: '⚙ Salir', de: '⚙ Beenden', fr: '⚙ Quitter', it: '⚙ Esci', pt: '⚙ Sair' },
  'course.lesson': { ru: 'Урок', en: 'Lesson', es: 'Lección', de: 'Lektion', fr: 'Leçon', it: 'Lezione', pt: 'Lição' },
  'course.line': { ru: 'строка', en: 'line', es: 'línea', de: 'Zeile', fr: 'ligne', it: 'riga', pt: 'linha' },
  'course.tip': { ru: 'Печатай ровно и точно — скорость придёт сама.', en: 'Type evenly and accurately — speed will follow.', es: 'Escribe parejo y preciso — la velocidad llegará.', de: 'Tippe gleichmäßig und genau — Tempo kommt von selbst.', fr: 'Tape régulièrement et précisément — la vitesse viendra.', it: 'Digita regolare e preciso — la velocità arriverà.', pt: 'Digita uniforme e preciso — a velocidade virá.' },
  'course.home': { ru: 'Домашний ряд', en: 'Home row', es: 'Fila base', de: 'Grundreihe', fr: 'Rangée de repos', it: 'Fila base', pt: 'Fila base' },
  'course.review': { ru: 'Повторение домашнего ряда', en: 'Home row review', es: 'Repaso de la fila base', de: 'Grundreihe wiederholen', fr: 'Révision rangée de repos', it: 'Ripasso fila base', pt: 'Revisão da fila base' },
  'course.keys': { ru: 'Новые клавиши', en: 'New keys', es: 'Teclas nuevas', de: 'Neue Tasten', fr: 'Nouvelles touches', it: 'Nuovi tasti', pt: 'Teclas novas' },
  'course.caps': { ru: 'Заглавные буквы (Shift)', en: 'Capitals (Shift)', es: 'Mayúsculas (Shift)', de: 'Großbuchstaben (Shift)', fr: 'Majuscules (Maj)', it: 'Maiuscole (Shift)', pt: 'Maiúsculas (Shift)' },
  'course.digits': { ru: 'Цифры', en: 'Numbers', es: 'Números', de: 'Zahlen', fr: 'Chiffres', it: 'Numeri', pt: 'Números' },
  'course.punct': { ru: 'Знаки препинания', en: 'Punctuation', es: 'Puntuación', de: 'Satzzeichen', fr: 'Ponctuation', it: 'Punteggiatura', pt: 'Pontuação' },
  'course.words': { ru: 'Частые слова', en: 'Common words', es: 'Palabras comunes', de: 'Häufige Wörter', fr: 'Mots fréquents', it: 'Parole comuni', pt: 'Palavras comuns' },
  'course.sentences': { ru: 'Предложения', en: 'Sentences', es: 'Frases', de: 'Sätze', fr: 'Phrases', it: 'Frasi', pt: 'Frases' },
  'tb.dark': { ru: 'Тёмная тема', en: 'Dark theme', es: 'Tema oscuro', de: 'Dunkles Thema', fr: 'Thème sombre', it: 'Tema scuro', pt: 'Tema escuro' },
  'tb.prev': { ru: '‹ Пред', en: '‹ Prev', es: '‹ Ant', de: '‹ Zurück', fr: '‹ Préc', it: '‹ Prec', pt: '‹ Ant' },
  'tb.next': { ru: 'След ›', en: 'Next ›', es: 'Sig ›', de: 'Weiter ›', fr: 'Suiv ›', it: 'Succ ›', pt: 'Próx ›' },
  // адаптив / прогресс / свой текст
  'weak.title': { ru: 'Слабые клавиши', en: 'Weak keys', es: 'Teclas débiles', de: 'Schwache Tasten', fr: 'Touches faibles', it: 'Tasti deboli', pt: 'Teclas fracas' },
  'weak.hint': { ru: 'Упражнение собрано из клавиш, где у тебя больше всего ошибок. «След» — новый набор.', en: 'Built from the keys you miss most. “Next” — a fresh set.', es: 'Hecho con las teclas que más fallas. «Sig» — un set nuevo.', de: 'Aus deinen Fehlertasten gebaut. „Weiter“ — neuer Satz.', fr: 'Construit à partir de tes touches ratées. « Suiv » — nouveau set.', it: 'Costruito dai tasti che sbagli di più. «Succ» — nuovo set.', pt: 'Feito das teclas que mais erras. «Próx» — novo conjunto.' },
  'weak.none': { ru: 'Пока мало данных — тренируем домашний ряд. Печатай ещё, и появятся твои слабые клавиши.', en: 'Not enough data yet — training the home row. Keep typing to reveal your weak keys.', es: 'Pocos datos aún — practicamos la fila base. Sigue escribiendo para ver tus teclas débiles.', de: 'Noch wenig Daten — wir üben die Grundreihe. Tippe weiter, um schwache Tasten zu zeigen.', fr: 'Peu de données — on entraîne la rangée de repos. Continue pour révéler tes touches faibles.', it: 'Pochi dati — alleniamo la fila base. Continua a scrivere per scoprire i tasti deboli.', pt: 'Poucos dados — treinamos a fila base. Continua a escrever para ver as teclas fracas.' },
  'prog.title': { ru: 'Прогресс по сессиям', en: 'Progress by session', es: 'Progreso por sesión', de: 'Fortschritt je Sitzung', fr: 'Progrès par session', it: 'Progresso per sessione', pt: 'Progresso por sessão' },
  'prog.empty': { ru: 'Недостаточно данных. Пройди хотя бы 2 упражнения — появится график скорости.', en: 'Not enough data. Finish at least 2 exercises to see the speed chart.', es: 'Datos insuficientes. Completa al menos 2 ejercicios para ver el gráfico.', de: 'Zu wenig Daten. Schließe mind. 2 Übungen ab, um das Diagramm zu sehen.', fr: 'Données insuffisantes. Termine au moins 2 exercices pour voir le graphique.', it: 'Dati insufficienti. Completa almeno 2 esercizi per il grafico.', pt: 'Dados insuficientes. Conclui pelo menos 2 exercícios para ver o gráfico.' },
  'prog.close': { ru: 'Закрыть', en: 'Close', es: 'Cerrar', de: 'Schließen', fr: 'Fermer', it: 'Chiudi', pt: 'Fechar' },
  'custom.title': { ru: 'Свой текст', en: 'Custom text', es: 'Texto propio', de: 'Eigener Text', fr: 'Texte perso', it: 'Testo tuo', pt: 'Texto próprio' },
  'custom.ph': { ru: 'Вставь любой текст для тренировки…', en: 'Paste any text to practice…', es: 'Pega cualquier texto para practicar…', de: 'Beliebigen Text zum Üben einfügen…', fr: 'Colle un texte pour t’entraîner…', it: 'Incolla un testo per esercitarti…', pt: 'Cola qualquer texto para praticar…' },
  'custom.start': { ru: 'Тренировать', en: 'Practice', es: 'Practicar', de: 'Üben', fr: 'S’entraîner', it: 'Allena', pt: 'Praticar' },
  'custom.cancel': { ru: 'Отмена', en: 'Cancel', es: 'Cancelar', de: 'Abbrechen', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar' },
  // статистика
  'st.exercises': { ru: 'упражнений', en: 'exercises', es: 'ejercicios', de: 'Übungen', fr: 'exercices', it: 'esercizi', pt: 'exercícios' },
  'st.done': { ru: 'пройдено', en: 'done', es: 'hechos', de: 'erledigt', fr: 'faits', it: 'fatti', pt: 'feitos' },
  'st.record': { ru: 'рекорд', en: 'best', es: 'récord', de: 'Rekord', fr: 'record', it: 'record', pt: 'recorde' },
  'st.wpm': { ru: 'WPM', en: 'WPM' },
  'st.accuracy': { ru: 'точность', en: 'accuracy', es: 'precisión', de: 'Genauigkeit', fr: 'précision', it: 'precisione', pt: 'precisão' },
  'st.errors': { ru: 'ошибок', en: 'errors', es: 'errores', de: 'Fehler', fr: 'fautes', it: 'errori', pt: 'erros' },
  'st.time': { ru: 'время', en: 'time', es: 'tiempo', de: 'Zeit', fr: 'temps', it: 'tempo', pt: 'tempo' },
  'st.streak': { ru: 'подряд', en: 'streak', es: 'seguidos', de: 'Serie', fr: 'd’affilée', it: 'di fila', pt: 'seguidos' },
  // подсказки и done
  'hint.flow': { ru: 'Поток: упражнения идут подряд без остановки.', en: 'Flow: exercises run back to back, no stops.', es: 'Flujo: los ejercicios van seguidos sin parar.', de: 'Fluss: Übungen laufen ohne Pause hintereinander.', fr: 'Flux : les exercices s’enchaînent sans pause.', it: 'Flusso: gli esercizi vanno di fila senza pause.', pt: 'Fluxo: os exercícios seguem sem parar.' },
  'hint.type': { ru: 'Печатай по образцу.', en: 'Type the pattern.', es: 'Escribe según el modelo.', de: 'Tippe nach Vorlage.', fr: 'Tape selon le modèle.', it: 'Digita secondo il modello.', pt: 'Digita conforme o modelo.' },
  'hint.block': { ru: 'Неверный символ не пропускается.', en: 'Wrong keys are not accepted.', es: 'No se aceptan teclas erróneas.', de: 'Falsche Tasten werden nicht akzeptiert.', fr: 'Les mauvaises touches sont refusées.', it: 'I tasti errati non sono accettati.', pt: 'Teclas erradas não são aceites.' },
  'hint.bs': { ru: 'Backspace — исправить.', en: 'Backspace to fix.', es: 'Retroceso para corregir.', de: 'Rücktaste zum Korrigieren.', fr: 'Retour arrière pour corriger.', it: 'Backspace per correggere.', pt: 'Backspace para corrigir.' },
  'hint.hidden': { ru: 'образец скрыт — печатай по памяти', en: 'pattern hidden — type from memory', es: 'modelo oculto — escribe de memoria', de: 'Vorlage verborgen — aus dem Gedächtnis tippen', fr: 'modèle masqué — tape de mémoire', it: 'modello nascosto — digita a memoria', pt: 'modelo oculto — digita de memória' },
  'done.title': { ru: '✓ Готово', en: '✓ Done', es: '✓ Listo', de: '✓ Fertig', fr: '✓ Terminé', it: '✓ Fatto', pt: '✓ Pronto' },
  'done.title.f': { ru: '✓ Отлично!', en: '✓ Great job!', es: '✓ ¡Genial!', de: '✓ Super!', fr: '✓ Bravo !', it: '✓ Ottimo!', pt: '✓ Excelente!' },
  'done.again': { ru: '↻ Заново', en: '↻ Again', es: '↻ Otra vez', de: '↻ Nochmal', fr: '↻ Encore', it: '↻ Ancora', pt: '↻ De novo' },
  'done.next': { ru: 'Следующее →', en: 'Next →', es: 'Siguiente →', de: 'Weiter →', fr: 'Suivant →', it: 'Successivo →', pt: 'Próximo →' },
  'err.load': { ru: 'Не удалось загрузить упражнения', en: 'Failed to load exercises', es: 'No se pudieron cargar los ejercicios', de: 'Übungen konnten nicht geladen werden', fr: 'Échec du chargement des exercices', it: 'Impossibile caricare gli esercizi', pt: 'Falha ao carregar exercícios' },
  // детский режим
  'k.title': { ru: '🐱 Котик-печатник', en: '🐱 Typing Cat', es: '🐱 Gato mecanógrafo', de: '🐱 Tipp-Katze', fr: '🐱 Chat dactylo', it: '🐱 Gatto dattilografo', pt: '🐱 Gato digitador' },
  'k.hello': { ru: 'Привет! Выбирай уровень — будем учиться печатать. Печатай точно, спешить не надо!', en: 'Hi! Pick a level and let’s learn to type. Be accurate — no need to rush!', es: '¡Hola! Elige un nivel y aprendamos a escribir. ¡Sé preciso, sin prisa!', de: 'Hallo! Wähle ein Level und lerne tippen. Sei genau — keine Eile!', fr: 'Salut ! Choisis un niveau et apprenons à taper. Sois précis, sans te presser !', it: 'Ciao! Scegli un livello e impariamo a scrivere. Sii preciso, senza fretta!', pt: 'Olá! Escolhe um nível e vamos aprender a digitar. Sê preciso, sem pressa!' },
  'k.rest': { ru: '🐱 Ты отлично позанимался! Передохни немножко 💛', en: '🐱 Great practice! Take a little break 💛', es: '🐱 ¡Buen trabajo! Descansa un poco 💛', de: '🐱 Tolle Übung! Mach eine kleine Pause 💛', fr: '🐱 Bravo ! Fais une petite pause 💛', it: '🐱 Bravo! Fai una piccola pausa 💛', pt: '🐱 Bom trabalho! Faz uma pausa 💛' },
  'k.block.ru': { ru: '🇷🇺 По-русски', en: '🇷🇺 Russian', es: '🇷🇺 Ruso', de: '🇷🇺 Russisch', fr: '🇷🇺 Russe', it: '🇷🇺 Russo', pt: '🇷🇺 Russo' },
  'k.block.en': { ru: '🇬🇧 По-английски', en: '🇬🇧 English', es: '🇬🇧 Inglés', de: '🇬🇧 Englisch', fr: '🇬🇧 Anglais', it: '🇬🇧 Inglese', pt: '🇬🇧 Inglês' },
  'k.level': { ru: 'Уровень', en: 'Level', es: 'Nivel', de: 'Level', fr: 'Niveau', it: 'Livello', pt: 'Nível' },
  'k.word': { ru: 'слово', en: 'word', es: 'palabra', de: 'Wort', fr: 'mot', it: 'parola', pt: 'palavra' },
  'k.noerr': { ru: '⭐ без ошибок', en: '⭐ no errors', es: '⭐ sin errores', de: '⭐ keine Fehler', fr: '⭐ sans fautes', it: '⭐ senza errori', pt: '⭐ sem erros' },
  'k.errors': { ru: 'ошибок', en: 'errors', es: 'errores', de: 'Fehler', fr: 'fautes', it: 'errori', pt: 'erros' },
  'k.passed': { ru: 'пройден!', en: 'passed!', es: '¡superado!', de: 'geschafft!', fr: 'réussi !', it: 'superato!', pt: 'concluído!' },
  'k.note3': { ru: 'Ни одной ошибки — ты звезда!', en: 'Not a single error — you are a star!', es: '¡Sin un solo error — eres una estrella!', de: 'Kein einziger Fehler — du bist ein Star!', fr: 'Pas une faute — tu es une star !', it: 'Nessun errore — sei una stella!', pt: 'Sem um único erro — és uma estrela!' },
  'k.note2': { ru: 'Очень здорово! Ещё чуть точнее — будет три звезды.', en: 'Very good! A bit more accurate for three stars.', es: '¡Muy bien! Un poco más preciso para tres estrellas.', de: 'Sehr gut! Etwas genauer für drei Sterne.', fr: 'Très bien ! Un peu plus précis pour trois étoiles.', it: 'Molto bene! Un po’ più preciso per tre stelle.', pt: 'Muito bem! Um pouco mais preciso para três estrelas.' },
  'k.note1': { ru: 'Уровень пройден! Попробуй ещё раз — получится точнее.', en: 'Level passed! Try again to be more accurate.', es: '¡Nivel superado! Inténtalo otra vez con más precisión.', de: 'Level geschafft! Versuch’s nochmal für mehr Genauigkeit.', fr: 'Niveau réussi ! Réessaie pour plus de précision.', it: 'Livello superato! Riprova per più precisione.', pt: 'Nível concluído! Tenta de novo com mais precisão.' },
  'k.again': { ru: '↻ Ещё раз', en: '↻ Again', es: '↻ Otra vez', de: '↻ Nochmal', fr: '↻ Encore', it: '↻ Ancora', pt: '↻ De novo' },
  'k.map': { ru: 'К карте', en: 'To map', es: 'Al mapa', de: 'Zur Karte', fr: 'À la carte', it: 'Alla mappa', pt: 'Ao mapa' },
  'k.next': { ru: 'Дальше →', en: 'Next →', es: 'Siguiente →', de: 'Weiter →', fr: 'Suivant →', it: 'Avanti →', pt: 'Próximo →' },
  'k.back': { ru: '← К карте', en: '← To map', es: '← Al mapa', de: '← Zur Karte', fr: '← À la carte', it: '← Alla mappa', pt: '← Ao mapa' },
  'k.startRu': { ru: 'Печатаем по-русски!', en: 'Typing in Russian!', es: '¡Escribimos en ruso!', de: 'Wir tippen Russisch!', fr: 'On tape en russe !', it: 'Scriviamo in russo!', pt: 'A digitar em russo!' },
  'k.startEn': { ru: 'Печатаем по-английски!', en: 'Typing in English!', es: '¡Escribimos en inglés!', de: 'Wir tippen Englisch!', fr: 'On tape en anglais !', it: 'Scriviamo in inglese!', pt: 'A digitar em inglês!' },
  // экзамен
  'ex.title': { ru: 'Тест печати', en: 'Typing Test', es: 'Prueba de mecanografía', de: 'Tipptest', fr: 'Test de frappe', it: 'Test di battitura', pt: 'Teste de digitação' },
  'ex.desc': { ru: 'Печатай предложения без остановки, пока не выйдет время. В конце — отчёт с Gross/Net WPM и точностью.', en: 'Type sentences non-stop until the time runs out. You get a report with Gross/Net WPM and accuracy.', es: 'Escribe frases sin parar hasta que acabe el tiempo. Al final, informe con WPM bruto/neto y precisión.', de: 'Tippe Sätze ohne Pause, bis die Zeit abläuft. Am Ende: Bericht mit Brutto/Netto-WPM und Genauigkeit.', fr: 'Tape des phrases sans arrêt jusqu’à la fin du temps. À la fin : rapport WPM brut/net et précision.', it: 'Digita frasi senza sosta fino allo scadere del tempo. Alla fine: report con WPM lordo/netto e precisione.', pt: 'Digita frases sem parar até o tempo acabar. No fim: relatório com WPM bruto/líquido e precisão.' },
  'ex.duration': { ru: 'Длительность', en: 'Duration', es: 'Duración', de: 'Dauer', fr: 'Durée', it: 'Durata', pt: 'Duração' },
  'ex.min': { ru: 'мин', en: 'min', es: 'min', de: 'Min', fr: 'min', it: 'min', pt: 'min' },
  'ex.target': { ru: 'Цель Net WPM', en: 'Target Net WPM', es: 'Objetivo WPM neto', de: 'Ziel Netto-WPM', fr: 'Objectif WPM net', it: 'Obiettivo WPM netto', pt: 'Meta WPM líquido' },
  'ex.name': { ru: 'Имя (для сертификата)', en: 'Name (for the certificate)', es: 'Nombre (para el certificado)', de: 'Name (für das Zertifikat)', fr: 'Nom (pour le certificat)', it: 'Nome (per il certificato)', pt: 'Nome (para o certificado)' },
  'ex.start': { ru: 'Начать тест', en: 'Start test', es: 'Empezar', de: 'Test starten', fr: 'Démarrer', it: 'Avvia test', pt: 'Iniciar teste' },
  'ex.cancel': { ru: 'Выйти', en: 'Exit', es: 'Salir', de: 'Beenden', fr: 'Quitter', it: 'Esci', pt: 'Sair' },
  'ex.left': { ru: 'осталось', en: 'left', es: 'restante', de: 'übrig', fr: 'restant', it: 'restante', pt: 'restante' },
  'ex.result': { ru: 'Результат теста', en: 'Test result', es: 'Resultado', de: 'Testergebnis', fr: 'Résultat', it: 'Risultato', pt: 'Resultado' },
  'ex.gross': { ru: 'Gross WPM', en: 'Gross WPM' },
  'ex.net': { ru: 'Net WPM', en: 'Net WPM' },
  'ex.keystrokes': { ru: 'нажатий', en: 'keystrokes', es: 'pulsaciones', de: 'Anschläge', fr: 'frappes', it: 'battute', pt: 'toques' },
  'ex.pass': { ru: 'СДАН', en: 'PASS', es: 'APROBADO', de: 'BESTANDEN', fr: 'RÉUSSI', it: 'SUPERATO', pt: 'APROVADO' },
  'ex.fail': { ru: 'НЕ СДАН', en: 'FAIL', es: 'NO APROBADO', de: 'NICHT BESTANDEN', fr: 'ÉCHEC', it: 'NON SUPERATO', pt: 'REPROVADO' },
  'ex.target.short': { ru: 'цель', en: 'target', es: 'meta', de: 'Ziel', fr: 'cible', it: 'obiettivo', pt: 'meta' },
  'ex.cert': { ru: '⬇ Сертификат (PNG)', en: '⬇ Certificate (PNG)', es: '⬇ Certificado (PNG)', de: '⬇ Zertifikat (PNG)', fr: '⬇ Certificat (PNG)', it: '⬇ Certificato (PNG)', pt: '⬇ Certificado (PNG)' },
  'ex.again': { ru: '↻ Ещё раз', en: '↻ Try again', es: '↻ Otra vez', de: '↻ Nochmal', fr: '↻ Réessayer', it: '↻ Riprova', pt: '↻ Tentar de novo' },
  'ex.cert.title': { ru: 'СЕРТИФИКАТ', en: 'CERTIFICATE', es: 'CERTIFICADO', de: 'ZERTIFIKAT', fr: 'CERTIFICAT', it: 'CERTIFICATO', pt: 'CERTIFICADO' },
  'ex.cert.sub': { ru: 'тест слепой печати', en: 'touch typing test', es: 'prueba de mecanografía', de: 'Tipptest', fr: 'test de dactylographie', it: 'test di dattilografia', pt: 'teste de digitação' },
  'ex.cert.date': { ru: 'Дата', en: 'Date', es: 'Fecha', de: 'Datum', fr: 'Date', it: 'Data', pt: 'Data' },
};

export function t(key: string): string {
  const e = DICT[key];
  if (!e) return key;
  return (e as Record<string, string>)[current] ?? e.en ?? key;
}
