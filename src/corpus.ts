// Корпусы для n-граммной модели (src/ngram.ts). Public-domain классика +
// бытовая лексика — чтобы покрыть частые биграммы/триграммы языка.
// EN дополнительно расширяется предложениями из банка abandon в рантайме.
// ES/DE/FR/IT/PT — ASCII (без диакритики), чтобы печаталось на нашей QWERTY-схеме.

export const CORPUS_RU = `
Мороз и солнце день чудесный ещё ты дремлешь друг прелестный пора красавица проснись открой сомкнуты негой взоры навстречу северной авроры звездою севера явись.
Буря мглою небо кроет вихри снежные крутя то как зверь она завоет то заплачет как дитя.
У лукоморья дуб зелёный златая цепь на дубе том и днём и ночью кот учёный всё ходит по цепи кругом идёт направо песнь заводит налево сказку говорит.
Жил старик со своею старухой у самого синего моря они жили в ветхой землянке ровно тридцать лет и три года старик ловил неводом рыбу старуха пряла свою пряжу.
Ветер по морю гуляет и кораблик подгоняет он бежит себе в волнах на раздутых парусах мимо острова крутого мимо города большого.
Уж небо осенью дышало уж реже солнышко блистало короче становился день лесов таинственная сень с печальным шумом обнажалась ложился на поля туман.
Скажи мне кудесник любимец богов что сбудется в жизни со мною и скоро ль на радость соседей врагов могильной засыплюсь землёю.
Не было бы счастья да несчастье помогло без труда не выловишь и рыбку из пруда тише едешь дальше будешь семь раз отмерь один раз отрежь.
Друзья мои прекрасен наш союз он как душа неразделим и вечен неколебим свободен и беспечен срастался он под сенью дружных муз.
Я помню чудное мгновенье передо мной явилась ты как мимолётное виденье как гений чистой красоты.
Сегодня хорошая погода завтра мы поедем в город купить хлеба молока и овощей на рынке всегда свежие фрукты и ягоды.
Работа над новым проектом идёт полным ходом команда собирается каждое утро чтобы обсудить план на день и распределить задачи между собой.
Книга лежала на столе рядом с лампой за окном медленно темнело и в комнате становилось всё тише только часы мерно отсчитывали минуты.
Человек привычка природа сила время вопрос ответ дорога город страна народ слово дело жизнь работа дружба радость надежда мечта.
`;

export const CORPUS_EN = `
The quick brown fox jumps over the lazy dog while the curious cat watches from the warm windowsill in the afternoon sun.
She sells seashells by the seashore and the shells she sells are surely seashells from the deep blue ocean.
Once upon a time in a quiet village there lived a young girl who loved to read books about distant lands and brave adventures.
The morning light filtered through the tall trees casting long shadows across the narrow path that wound its way toward the river.
Knowledge is power and reading is the key that opens the door to a world of endless learning and discovery for everyone.
Practice makes perfect so keep typing every single day and soon your fingers will dance across the keyboard without effort.
The old clock on the wall ticked softly as the rain fell gently against the glass and the fire crackled in the hearth.
People often forget that small steps taken consistently lead to great results over time so be patient and trust the process.
Water flows down the mountain stream past the smooth grey stones and gathers in a clear pool beneath the ancient oak tree.
Our team works hard each week to build better software that helps people learn new skills and reach their personal goals.
Bright stars filled the night sky above the silent forest where an owl called out and a soft wind stirred the fallen leaves.
The chef prepared a simple meal of fresh bread warm soup and ripe fruit which they shared with friends around the table.
Every great journey begins with a single step and the courage to leave the comfort of the familiar behind for a while.
Time and tide wait for no one so make the most of each day and never put off until tomorrow what you can do today.
`;

export const CORPUS_ES = `
En un lugar de la mancha de cuyo nombre no quiero acordarme vivia un hidalgo de los de lanza en astillero y galgo corredor.
La vida es sueno y los suenos suenos son dijo el poeta mientras el sol caia despacio tras las montanas lejanas del sur.
Cada manana tomamos cafe con leche y pan tostado antes de salir al trabajo por las calles llenas de gente y de ruido.
El nino corria por el parque persiguiendo una pelota mientras su madre leia un libro sentada junto a la fuente clara.
Nuestro equipo trabaja cada dia para construir un programa mejor que ayude a las personas a aprender nuevas habilidades.
El agua del rio baja de la montana entre piedras grises y se junta en un lago tranquilo bajo el viejo arbol verde.
Quien mucho abarca poco aprieta y mas vale tarde que nunca por eso conviene tener calma y paciencia en todo momento.
Las estrellas brillan sobre el bosque silencioso donde el viento mueve las hojas y un buho canta en la noche oscura.
`;

export const CORPUS_DE = `
Wer reisen will der schweige fein geh stets zu fuss und nehme seinen guten mut und ein paar feste schuhe mit sich.
Am morgen trinken wir kaffee mit milch und essen frisches brot bevor wir zur arbeit durch die lauten strassen gehen.
Das kind lief durch den park und jagte einem bunten ball nach waehrend die mutter ruhig auf der bank ein buch las.
Unser team arbeitet jeden tag hart um bessere software zu bauen die menschen hilft neue faehigkeiten zu lernen.
Das wasser fliesst vom berg durch graue steine und sammelt sich in einem stillen see unter der alten gruenen eiche.
Uebung macht den meister also tippe jeden tag ein wenig und bald tanzen deine finger ohne muehe ueber die tasten.
Helle sterne fuellen den nachthimmel ueber dem stillen wald wo eine eule ruft und der wind die blaetter bewegt.
Kleine schritte die man stetig macht fuehren mit der zeit zu grossen ergebnissen also sei geduldig und vertraue.
`;

export const CORPUS_FR = `
Il etait une fois dans un village tranquille une jeune fille qui aimait lire des livres sur des pays lointains.
Chaque matin nous prenons un cafe au lait et du pain grille avant de sortir travailler dans les rues bruyantes.
L enfant courait dans le parc en poursuivant un ballon tandis que sa mere lisait un livre assise pres de la fontaine.
Notre equipe travaille chaque jour pour creer un meilleur logiciel qui aide les gens a apprendre de nouvelles choses.
L eau de la riviere descend de la montagne entre les pierres grises et se rassemble dans un lac calme sous le chene.
C est en forgeant que l on devient forgeron alors tape un peu chaque jour et tes doigts danseront sur le clavier.
Les etoiles brillent sur la foret silencieuse ou le vent agite les feuilles et un hibou chante dans la nuit noire.
Petit a petit l oiseau fait son nid et de petits pas reguliers menent avec le temps a de grands resultats heureux.
`;

export const CORPUS_IT = `
Nel mezzo del cammin di nostra vita mi ritrovai per una selva oscura che la diritta via era smarrita del tutto.
Ogni mattina prendiamo un caffe con il latte e del pane tostato prima di uscire a lavorare per le strade affollate.
Il bambino correva nel parco inseguendo una palla mentre sua madre leggeva un libro seduta vicino alla fontana chiara.
La nostra squadra lavora ogni giorno per costruire un programma migliore che aiuti le persone a imparare cose nuove.
L acqua del fiume scende dalla montagna tra le pietre grigie e si raccoglie in un lago tranquillo sotto la quercia.
La pratica rende perfetti quindi scrivi un poco ogni giorno e presto le tue dita danzeranno sulla tastiera leggere.
Le stelle brillano sopra il bosco silenzioso dove il vento muove le foglie e un gufo canta nella notte profonda.
Chi va piano va sano e va lontano e piccoli passi costanti portano col tempo a grandi e felici risultati sicuri.
`;

export const CORPUS_PT = `
Era uma vez numa aldeia tranquila uma jovem que adorava ler livros sobre terras distantes e grandes aventuras.
Todas as manhas tomamos cafe com leite e pao torrado antes de sair para trabalhar pelas ruas cheias de gente.
A crianca corria pelo parque perseguindo uma bola enquanto a mae lia um livro sentada junto da fonte de agua clara.
A nossa equipa trabalha todos os dias para construir um programa melhor que ajude as pessoas a aprender novas coisas.
A agua do rio desce da montanha por entre as pedras cinzentas e junta se num lago calmo sob o velho carvalho verde.
A pratica leva a perfeicao por isso escreve um pouco cada dia e em breve os teus dedos vao dancar sobre o teclado.
As estrelas brilham sobre a floresta silenciosa onde o vento move as folhas e uma coruja canta na noite escura.
Devagar se vai ao longe e pequenos passos constantes levam com o tempo a grandes e felizes resultados certos.
`;

// карта язык → корпус (для n-граммной генерации в AI-режиме на 7 языках)
export const CORPUS: Record<string, string> = {
  ru: CORPUS_RU, en: CORPUS_EN, es: CORPUS_ES, de: CORPUS_DE, fr: CORPUS_FR, it: CORPUS_IT, pt: CORPUS_PT,
};
