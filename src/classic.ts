// Банк «Классика» — сложные литературные тексты public-domain на 7 языках
// (запрос Дениса 13.06.2026: «сложные литературные тексты», М&М нельзя — права до ~2038).
// Источники Wikisource: RU Пушкин «Евгений Онегин»; EN Shakespeare Sonnets 18/116;
// ES Cervantes «Don Quijote»; DE Kafka «Die Verwandlung»; FR Proust «Du côté de chez Swann»;
// IT Dante «Divina Commedia» (Inferno I); PT Machado de Assis «Dom Casmurro».
// Латинские нормализованы в ASCII; проза перенесена по словам (~58); символы вычищены.
import type { Lang } from './i18n';
import type { Exercise } from './content';

export const CLASSIC_TITLE: Record<string, string> = {"ru": "Пушкин — Евгений Онегин", "en": "Shakespeare — Sonnets", "es": "Cervantes — Don Quijote", "de": "Kafka — Die Verwandlung", "fr": "Proust — Du côté de chez Swann", "it": "Dante — Divina Commedia", "pt": "Machado de Assis — Dom Casmurro"};

export const CLASSIC: Record<string, string[][]> = {
  "ru": [
    [
      "Мой дядя самых честных правил,",
      "Когда не в шутку занемог,",
      "Он уважать себя заставил",
      "И лучше выдумать не мог;",
      "Его пример другим наука;",
      "Но, Боже мой, какая скука",
      "С больным сидеть и день и ночь,",
      "Не отходя ни шагу прочь!",
      "Какое низкое коварство",
      "Полуживого забавлять,",
      "Ему подушки поправлять,",
      "Печально подносить лекарство,",
      "Вздыхать и думать про себя:",
      "Когда же чёрт возьмёт тебя!"
    ],
    [
      "Так думал молодой повеса,",
      "Летя в пыли на почтовых,",
      "Всевышней волею Зевеса",
      "Наследник всех своих родных.",
      "Друзья Людмилы и Руслана!",
      "С героем моего романа",
      "Без предисловий сей же час",
      "Позвольте познакомить вас:",
      "Онегин, добрый мой приятель,",
      "Родился на брегах Невы,",
      "Где, может быть, родились вы",
      "Или блистали, мой читатель!",
      "Там некогда гулял и я:",
      "Но вреден север для меня."
    ]
  ],
  "en": [
    [
      "Shall I compare thee to a summer's day?",
      "Thou art more lovely and more temperate:",
      "Rough winds do shake the darling buds of May,",
      "And summer's lease hath all too short a date:",
      "Sometime too hot the eye of heaven shines,",
      "And often is his gold complexion dimm'd;",
      "And every fair from fair sometime declines,",
      "By chance, or nature's changing course untrimm'd;",
      "But thy eternal summer shall not fade,",
      "Nor lose possession of that fair thou ow'st,",
      "Nor shall death brag thou wander'st in his shade,",
      "When in eternal lines to time thou grow'st;",
      "So long as man can breathe, or eyes can see,",
      "So long lives this, and this gives life to thee."
    ],
    [
      "Let me not to the marriage of true minds",
      "Admit impediments. Love is not love",
      "Which alters when it alteration finds,",
      "Or bends with the remover to remove:",
      "O, no! it is an ever-fixed mark,",
      "That looks on tempests and is never shaken;",
      "It is the star to every wandering bark,",
      "Whose worth's unknown, although his height be taken.",
      "Love's not Time's fool, though rosy lips and cheeks",
      "Within his bending sickle's compass come;",
      "Love alters not with his brief hours and weeks,",
      "But bears it out even to the edge of doom.",
      "If this be error, and upon me prov'd,",
      "I never writ, nor no man ever lov'd."
    ]
  ],
  "es": [
    [
      "En un lugar de la Mancha, de cuyo nombre no quiero",
      "acordarme, no ha mucho tiempo que vivia un hidalgo de los",
      "de lanza en astillero, adarga antigua, rocin flaco y galgo",
      "corredor. Una olla de algo mas vaca que carnero, salpicon",
      "las mas noches, duelos y quebrantos los sabados, lantejas",
      "los viernes, algun palomino de anadidura los domingos,",
      "consumian las tres partes de su hacienda."
    ],
    [
      "Frisaba la edad de nuestro hidalgo con los cincuenta anos:",
      "era de complexion recia, seco de carnes, enjuto de rostro,",
      "gran madrugador y amigo de la caza. En resolucion, se",
      "enfrasco tanto en su lectura, que se le pasaban las noches",
      "leyendo de claro en claro, y los dias de turbio en turbio;",
      "y asi del poco dormir y del mucho leer se le seco el",
      "celebro de manera, que vino a perder el juicio."
    ]
  ],
  "de": [
    [
      "Als Gregor Samsa eines Morgens aus unruhigen Traumen",
      "erwachte, fand er sich in seinem Bett zu einem ungeheueren",
      "Ungeziefer verwandelt. Er lag auf seinem panzerartig",
      "harten Rucken und sah, wenn er den Kopf ein wenig hob,",
      "seinen gewolbten, braunen, von bogenformigen Versteifungen",
      "geteilten Bauch, auf dessen Hohe sich die Bettdecke, zum",
      "ganzlichen Niedergleiten bereit, kaum noch erhalten",
      "konnte."
    ],
    [
      "Was ist mit mir geschehen? dachte er. Es war kein Traum,",
      "sein Zimmer, ein richtiges, nur etwas zu kleines",
      "Menschenzimmer, lag ruhig zwischen den vier wohlbekannten",
      "Wanden. Gregors Blick richtete sich dann zum Fenster, und",
      "das trube Wetter machte ihn ganz melancholisch."
    ]
  ],
  "fr": [
    [
      "Longtemps, je me suis couche de bonne heure. Parfois, a",
      "peine ma bougie eteinte, mes yeux se fermaient si vite que",
      "je n'avais pas le temps de me dire: \" Je m'endors. \" Et,",
      "une demi-heure apres, la pensee qu'il etait temps de",
      "chercher le sommeil m'eveillait; je voulais poser le",
      "volume que je croyais avoir encore dans les mains et",
      "souffler ma lumiere."
    ],
    [
      "Je n'avais pas cesse en dormant de faire des reflexions",
      "sur ce que je venais de lire, mais ces reflexions avaient",
      "pris un tour un peu particulier; il me semblait que",
      "j'etais moi-meme ce dont parlait l'ouvrage: une eglise, un",
      "quatuor, la rivalite de Francois Ier et de Charles-Quint."
    ]
  ],
  "it": [
    [
      "Nel mezzo del cammin di nostra vita",
      "mi ritrovai per una selva oscura,",
      "che la diritta via era smarrita.",
      "Ahi quanto a dir qual era e cosa dura",
      "esta selva selvaggia e aspra e forte",
      "che nel pensier rinova la paura!"
    ],
    [
      "Tant'e amara che poco e piu morte;",
      "ma per trattar del ben ch'i' vi trovai,",
      "diro de l'altre cose ch'i' v'ho scorte.",
      "Io non so ben ridir com'i' v'intrai,",
      "tant'era pien di sonno a quel punto",
      "che la verace via abbandonai."
    ],
    [
      "Ma poi ch'i' fui al pie d'un colle giunto,",
      "la dove terminava quella valle",
      "che m'avea di paura il cor compunto,",
      "guardai in alto e vidi le sue spalle",
      "vestite gia de' raggi del pianeta",
      "che mena dritto altrui per ogne calle."
    ]
  ],
  "pt": [
    [
      "Uma noite destas, vindo da cidade para o Engenho Novo,",
      "encontrei no trem da Central um rapaz aqui do bairro, que",
      "eu conheco de vista e de chapeo. Comprimentou-me, sentou-",
      "se ao pe de mim, falou da lua e dos ministros, e acabou",
      "recitando-me versos. A viagem era curta, e os versos pode",
      "ser que nao fossem inteiramente maus."
    ],
    [
      "Nao consultes diccionarios. Casmurro nao esta aqui no",
      "sentido que elles lhe dao, mas no que lhe poz o vulgo de",
      "homem calado e mettido comsigo. Dom veiu por ironia, para",
      "attribuir-me fumos de fidalgo. Tambem nao achei melhor",
      "titulo para a minha narracao; se nao tiver outro daqui ate",
      "ao fim do livro, vae este mesmo."
    ]
  ]
};

/** Упражнения банка «Классика» на языке интерфейса L (фолбэк — английский). */
export function classicExercises(L: Lang): Exercise[] {
  const st = CLASSIC[L] ?? CLASSIC.en;
  const title = CLASSIC_TITLE[L] ?? CLASSIC_TITLE.en;
  return st.map((lines, i) => ({
    id: `classic-${L}-${i + 1}`,
    bank: 'classic' as const,
    title: `${title} - ${i + 1}/${st.length}`,
    lines,
  }));
}
