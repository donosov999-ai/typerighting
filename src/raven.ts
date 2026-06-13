// Банк «готовых текстов» — «Ворон» Эдгара По на 7 языках (идея Дениса 13.06.2026).
// Канонические public-domain переводы из Wikisource: RU Бальмонт (1894), ES Pérez Bonalde,
// DE Hedwig Lachmann (1891), FR Maurice Rollinat, IT Ernesto Ragazzoni (1896), PT Fernando Pessoa.
// Латинские нормализованы в ASCII (диакритика убрана) — печатаются на QWERTY нашей раскладки.
// Сгенерировано scripts из /tmp/raven_<lang>.txt; первые 6 строф каждого.
import type { Lang } from './i18n';
import type { Exercise } from './content';

export const RAVEN_TITLE: Record<string, string> = {"ru": "Ворон", "en": "The Raven", "es": "El cuervo", "de": "Der Rabe", "fr": "Le Corbeau", "it": "Il corvo", "pt": "O Corvo"};

// [язык] -> строфы -> строки для печати
export const RAVEN: Record<string, string[][]> = {
  "ru": [
    [
      "Как-то в полночь, в час угрюмый, полный тягостною думой,",
      "Над старинными томами я склонялся в полусне,",
      "Грёзам странным отдавался, вдруг неясный звук раздался,",
      "Будто кто-то постучался - постучался в дверь ко мне.",
      "\"Это верно\", прошептал я, \"гость в полночной тишине,",
      "Гость стучится в дверь ко мне\"."
    ],
    [
      "Ясно помню... Ожиданья... Поздней осени рыданья...",
      "И в камине очертанья тускло тлеющих углей...",
      "О, как жаждал я рассвета, как я тщётно ждал ответа",
      "На страданье, без привета, на вопрос о ней, о ней,",
      "О Леноре, что блистала ярче всех земных огней,",
      "О светиле прежних дней."
    ],
    [
      "И завес пурпурных трепет издавал как будто лепет,",
      "Трепет, лепет, наполнявший тёмным чувством сердце мне.",
      "Непонятный страх смиряя, встал я с места, повторяя: -",
      "\"Это только гость, блуждая, постучался в дверь ко мне,",
      "Поздний гость приюта просит в полуночной тишине -",
      "Гость стучится в дверь ко мне\"."
    ],
    [
      "Подавив свои сомненья, победивши опасенья,",
      "Я сказал: \"Не осудите замедленья моего!",
      "Этой полночью ненастной я вздремнул, и стук неясный",
      "Слишком тих был, стук неясный, - и не слышал я его,",
      "Я не слышал\" - тут раскрыл я дверь жилища моего: -",
      "Тьма, и больше ничего."
    ],
    [
      "Взор застыл, во тьме стеснённый, и стоял я изумлённый,",
      "Снам отдавшись, недоступным на земле ни для кого;",
      "Но как прежде ночь молчала, тьма душе не отвечала,",
      "Лишь - \"Ленора!\" - прозвучало имя солнца моего, -",
      "Это я шепнул, и эхо повторило вновь его, -",
      "Эхо, больше ничего."
    ],
    [
      "Вновь я в комнату вернулся - обернулся - содрогнулся, -",
      "Стук раздался, но слышнее, чем звучал он до того.",
      "\"Верно, что-нибудь сломилось, что-нибудь пошевелилось,",
      "Там, за ставнями, забилось у окошка моего,",
      "Это ветер, усмирю я трепет сердца моего, -",
      "Ветер, больше ничего\"."
    ]
  ],
  "en": [
    [
      "Once upon a midnight dreary, while I pondered, weak and weary,",
      "Over many a quaint and curious volume of forgotten lore,-",
      "While I nodded, nearly napping, suddenly there came a tapping,",
      "As of some one gently rapping, rapping at my chamber door.",
      "\"'Tis some visitor,\" I muttered, \"tapping at my chamber door;",
      "Only this, and nothing more.\""
    ],
    [
      "Ah, distinctly I remember, it was in the bleak December,",
      "And each separate dying ember wrought its ghost upon the floor.",
      "Eagerly I wished the morrow; vainly I had sought to borrow",
      "From my books surcease of sorrow, - sorrow for the lost Lenore,-",
      "For the rare and radiant maiden whom the angels named Lenore,-",
      "Nameless here forevermore."
    ],
    [
      "And the silken, sad, uncertain rustling of each purple curtain",
      "Thrilled me, - filled me with fantastic terrors never felt before;",
      "So that now, to still the beating of my heart, I stood repeating,",
      "\"'Tis some visitor entreating entrance at my chamber door, -",
      "Some late visitor entreating entrance at my chamber door;",
      "That it is, and nothing more.\""
    ],
    [
      "Presently my soul grew stronger; hesitating then no longer,",
      "\"Sir,\" said I, \"or madam, truly your forgiveness I implore;",
      "But the fact is, I was napping, and so gently you came rapping,",
      "And so faintly you came tapping, tapping at my chamber door,",
      "That I scarce was sure I heard you.\" - Here I opened wide the door;",
      "Darkness there, and nothing more."
    ],
    [
      "Deep into that darkness peering, long I stood there, wondering, fearing,",
      "Doubting, dreaming dreams no mortal ever dared to dream before;",
      "But the silence was unbroken, and the darkness gave no token,",
      "And the only word there spoken was the whispered word \"Lenore!\"",
      "This I whispered, and an echo murmured back the word \"Lenore!\"",
      "Merely this, and nothing more."
    ],
    [
      "Back into the chamber turning, all my soul within me burning,",
      "Soon again I heard a tapping, something louder than before:",
      "\"Surely,\" said I, \"surely that is something at my window-lattice;",
      "Let me see then what thereat is, and this mystery explore,-",
      "Let my heart be still a moment, and this mystery explore;-",
      "'Tis the wind, and nothing more.\""
    ]
  ],
  "es": [
    [
      "Una fosca media noche, cuando en tristes reflexiones,",
      "sobre mas de un raro infolio de olvidados cronicones",
      "inclinaba sonoliento la cabeza, de repente",
      "a mi puerta oi llamar:",
      "como si alguien, suavemente, se pusiese con incierta",
      "mano timida a tocar:",
      "\"Es una visita que llamando esta a mi puerta:",
      "eso es todo y nada mas!\""
    ],
    [
      "Ah! Bien claro lo recuerdo: era el crudo mes del hielo,",
      "y su espectro cada brasa moribunda enviaba al suelo.",
      "Cuan ansioso el nuevo dia deseaba, en la lectura",
      "procurando en vano hallar",
      "tregua a la honda desventura de la muerte de Leonora,",
      "la radiante, la sin par",
      "virgen pura a quien Leonora los querubes llaman, hora",
      "ya sin nombre... nunca mas!"
    ],
    [
      "Y el crujido triste, incierto, de las rojas colgaduras",
      "me aterraba, me llenaba de fantasticas pavuras,",
      "de tal modo que el latido de mi pecho palpitante",
      "procurando dominar,",
      "\"es, sin duda, un visitante que a mi alcoba quiere entrar:",
      "un tardio visitante a las puertas de mi estancia..",
      "eso es todo, y nada mas!\""
    ]
  ],
  "de": [
    [
      "Eines Nachts aus gelben Blattern mit verblichnen Runenlettern",
      "Tote Mahren suchend, sammelnd, von des Zeitenmeers Gestaden,",
      "Mude in die Zeilen blickend und zuletzt im Schlafe nickend,",
      "Hort' ich plotzlich leise klopfen, leise doch vernehmlich klopfen",
      "Und fuhr auf erschrocken stammelnd: \"Einer von den Kameraden,\"",
      "\"Einer von den Kameraden!\""
    ],
    [
      "In dem letzten Mond des Jahres, um die zwolfte Stunde war es,",
      "Und ein wunderlich Rumoren klang mir fort und fort im Ohre,",
      "Sehnlichst harrte ich des Tages, jedes neuen Glockenschlages,",
      "In das Buch vor mir versenken wollt' ich all mein trub' Gedenken,",
      "Meine Traume von Lenoren, meinen Schmerz um Leonore,",
      "Um die tote Leonore."
    ],
    [
      "Seltsame, phantastisch wilde, unerklarliche Gebilde,",
      "Schwarz und dicht gleich undurchsicht'gen, nachtig dunklen Nebelschwaden",
      "Huschten aus den Zimmerecken, fullten mich mit tausend Schrecken,",
      "So dass ich nun bleich und schlotternd, immer wieder angstvoll stotternd,",
      "Murmelte, mich zu beschwicht'gen: \"Einer von den Kameraden,\"",
      "\"Einer von den Kameraden!\""
    ],
    [
      "Alsbald aber mich ermannend, fragt' ich jede Scheu verbannend,",
      "Wen der Weg noch zu mir fuhre: Mit wem habe ich die Ehre,",
      "Hub ich an weltmannisch hoflich, Sie verzeihen, ich bin straflich,",
      "Dass ich Sie nicht gleich vernommen, seien Sie mir hochwillkommen,",
      "Hiemit offnet' ich die Thure - nichts als schaudervolle Leere,",
      "Schwarze, schaudervolle Leere."
    ]
  ],
  "fr": [
    [
      "Vers le sombre minuit, tandis que fatigue",
      "J'etais a mediter sur maint volume rare",
      "Pour tout autre que moi dans l'oubli relegue,",
      "Pendant que je plongeais dans un reve bizarre,",
      "Il se fit tout a coup comme un tapotement",
      "De quelqu'un qui viendrait frapper tout doucement",
      "Chez moi. Je dis alors, baillant, d'une voix morte :",
      "\" C'est quelque visiteur - oui - qui frappe a ma porte :",
      "C'est cela seul et rien de plus ! \""
    ],
    [
      "Ah ! tres distinctement je m'en souviens ! c'etait",
      "Par un apre decembre - au fond du foyer pale,",
      "Chaque braise a son tour lentement s'emiettait,",
      "En brodant le plancher du reflet de son rale.",
      "Avide du matin, le regard indecis,",
      "J'avais lu, sans que ma tristesse eut un sursis,",
      "Ma tristesse pour l'ange enfui dans le mystere,",
      "Que l'on nomme la-haut Lenore, et que sur terre",
      "On ne nommera jamais plus !"
    ],
    [
      "Et les rideaux pourpres sortaient de la torpeur,",
      "Et leur soyeuse voix si triste et si menue",
      "Me faisait tressaillir, m'emplissait d'une peur",
      "Fantastique et pour moi jusqu'alors inconnue :",
      "Si bien que pour calmer enfin le battement",
      "De mon coeur, je redis debout : \" Evidemment",
      "C'est quelqu'un attarde qui, par ce noir decembre,",
      "Est venu frapper a la porte de ma chambre ;",
      "C'est cela meme et rien de plus. \""
    ]
  ],
  "it": [
    [
      "Una volta, a mezzanotte, mentre stanco e affaticato",
      "meditavo sovra un raro, strano codice obliato,",
      "e la testa grave e assorta - non reggevami piu su,",
      "fui destato all'improvviso da un romore alla mia porta.",
      "Un viatore, un pellegrino, bussa, dissi, alla mia porta,",
      "solo questo e nulla piu!"
    ],
    [
      "Oh ricordo era il dicembre e il riflesso sonnolento",
      "dei tizzoni in agonia ricamava il pavimento.",
      "Triste avevo invan l'aurora chiesto e invano una virtu",
      "a' miei libri, per scordare la perduta mia Lenora,",
      "la raggiante, santa vergine che in ciel chiamano Lenora",
      "e qui nome or non ha piu!"
    ],
    [
      "E il severo, vago, morbido, ondeggiare dei velluti",
      "mi riempiva, penetrava di terrori sconosciuti!",
      "tanto infine che, a far corta quell'angoscia, m'alzai su",
      "mormorando: e un pellegrino che ha battuto alla mia porta,",
      "un viatore o un pellegrino che ha battuto alla mia porta,",
      "questo, e nulla, nulla piu!"
    ],
    [
      "Calmo allor, cacciate alfine quelle immagini confuse,",
      "mossi un passo, e: \"Signor\" dissi, o signora, mille scuse!",
      "ma vi giuro, tanto assorta m'era l'anima e quassu",
      "tanto piano, tanto lieve voi bussaste alla mia porta,",
      "ch'io non sono ancor ben certo d'esser desto\". Aprii la porta:",
      "Un gran buio e nulla piu!"
    ]
  ],
  "pt": [
    [
      "Numa meia-noite agreste, quando eu lia, lento e triste,",
      "Vagos, curiosos tomos de sciencias ancestraes,",
      "E ja quasi adormecia, ouvi o que parecia",
      "O som de alguem que batia levemente a meus humbraes.",
      "\"Uma visita\", eu me disse, \"esta batendo a meus humbraes.",
      "E' so isto, e nada mais.\""
    ],
    [
      "Ah, que bem d'isso me lembro! Era no frio dezembro,",
      "E o fogo, morrendo negro, urdia sombras deseguaes.",
      "Como eu qu'ria a madrugada, toda a noite aos livros dada",
      "P'ra esquecer (em vao!) a amada, hoje entre hostes celestiaes -",
      "Essa cujo nome sabem as hostes celestiaes,",
      "Mas sem nome aqui jamais!"
    ],
    [
      "Como, a tremer frio e frouxo, cada reposteiro roxo",
      "Me incutia, urdia extranhos terrores nunca antes taes!",
      "Mas, a mim mesmo infundindo forca, eu ia repetindo,",
      "\"E' uma visita pedindo entrada aqui em meus humbraes;",
      "Uma visita tardia pede entrada em meus humbraes.",
      "E' so isto, e nada mais.\""
    ],
    [
      "E, mais forte num instante, ja nem tardo ou hesitante,",
      "\"Senhor\" eu disse, \"ou senhora, decerto me desculpaes;",
      "Mas eu ia adormecendo, quando viestes batendo,",
      "Tao levemente batendo, batendo por meus humbraes,",
      "Que mal ouvi... \" E abri largos, franqueando-os, meus humbraes.",
      "Noite, noite e nada mais."
    ]
  ]
};

/** Упражнения банка стихов «Ворон» на языке интерфейса L (фолбэк — английский). */
export function ravenExercises(L: Lang): Exercise[] {
  const st = RAVEN[L] ?? RAVEN.en;
  const title = RAVEN_TITLE[L] ?? RAVEN_TITLE.en;
  return st.map((lines, i) => ({
    id: `raven-${L}-${i + 1}`,
    bank: 'poemHymn' as const,
    title: `${title} - ${i + 1}/${st.length}`,
    lines,
  }));
}
