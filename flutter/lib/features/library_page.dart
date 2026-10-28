import 'package:flutter/material.dart';

import '../design_system/templates.dart';

/// C1 «Библиотека упражнений»: the practice banks of the interface language
/// with their real exercise counts and how many are done (tr_progress_*).
/// Filter chips and search narrow the list; a card opens the trainer.
class LibraryBank {
  const LibraryBank(this.id, this.count, this.done);
  final String id;
  final int count, done;
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.language,
    required this.tr,
    required this.banks,
    required this.onOpen,
  });
  final String language;
  final String Function(String) tr;
  final List<LibraryBank> banks;
  final ValueChanged<String> onOpen;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

const _bankIcon = {
  'classic': Icons.menu_book_outlined,
  'poemHymn': Icons.history_edu,
  'ruWords': Icons.abc,
  'ruPhrases': Icons.chat_bubble_outline,
  'digits': Icons.pin_outlined,
};

String libraryCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'title': [
      'Библиотека упражнений',
      'Exercise library',
      'Biblioteca de ejercicios',
      'Übungsbibliothek',
      'Bibliothèque d’exercices',
      'Libreria di esercizi',
      'Biblioteca de exercícios',
    ],
    'sub': [
      'Выберите набор, чтобы начать практику',
      'Pick a set to start practising',
      'Elige un conjunto para practicar',
      'Wähle ein Set zum Üben',
      'Choisissez une série pour commencer',
      'Scegli una serie per esercitarti',
      'Escolha um conjunto para praticar',
    ],
    'search': [
      'Найти набор…',
      'Find a set…',
      'Buscar…',
      'Suchen…',
      'Rechercher…',
      'Cerca…',
      'Procurar…',
    ],
    'all': ['Все', 'All', 'Todos', 'Alle', 'Tous', 'Tutti', 'Todos'],
    'exercises': [
      'упражнений',
      'exercises',
      'ejercicios',
      'Übungen',
      'exercices',
      'esercizi',
      'exercícios',
    ],
    'done': [
      'пройдено',
      'done',
      'hechos',
      'erledigt',
      'faits',
      'fatti',
      'feitos',
    ],
    'none': [
      'Ничего не найдено',
      'Nothing found',
      'Sin resultados',
      'Nichts gefunden',
      'Aucun résultat',
      'Nessun risultato',
      'Nada encontrado',
    ],
    'classic.d': [
      'Известные тексты и отрывки',
      'Well-known texts and passages',
      'Textos y fragmentos conocidos',
      'Bekannte Texte und Auszüge',
      'Textes et extraits connus',
      'Testi e brani noti',
      'Textos e trechos conhecidos',
    ],
    'poemHymn.d': [
      'Поэтические тексты',
      'Poetry',
      'Textos poéticos',
      'Gedichte',
      'Textes poétiques',
      'Testi poetici',
      'Textos poéticos',
    ],
    'ruWords.d': [
      'Частые слова — от коротких к длинным',
      'Frequent Russian words, short to long',
      'Palabras rusas frecuentes',
      'Häufige russische Wörter',
      'Mots russes fréquents',
      'Parole russe frequenti',
      'Palavras russas frequentes',
    ],
    'ruPhrases.d': [
      'Полезные фразы на каждый день',
      'Everyday Russian phrases',
      'Frases rusas cotidianas',
      'Russische Alltagssätze',
      'Phrases russes du quotidien',
      'Frasi russe quotidiane',
      'Frases russas do dia a dia',
    ],
    'digits.d': [
      'Числа, даты, суммы',
      'Numbers, dates, amounts',
      'Números, fechas, importes',
      'Zahlen, Daten, Beträge',
      'Nombres, dates, montants',
      'Numeri, date, importi',
      'Números, datas, valores',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class _LibraryPageState extends State<LibraryPage> {
  String? filter;
  String query = '';

  /// Bank titles carry flag/book emoji in the source dictionary.
  String name(String id) => widget
      .tr('bank.$id')
      .replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}\u{1F4D6}]', unicode: true), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    String c(String k) => libraryCopy(widget.language, k);
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    final shown = widget.banks
        .where((b) => filter == null || b.id == filter)
        .where(
          (b) =>
              query.isEmpty ||
              name(b.id).toLowerCase().contains(query.toLowerCase()) ||
              c('${b.id}.d').toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c('sub'), style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => query = v.trim()),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: c('search'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(c('all')),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
                for (final b in widget.banks)
                  ChoiceChip(
                    label: Text(name(b.id)),
                    selected: filter == b.id,
                    onSelected: (_) => setState(() => filter = b.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(c('none'), textAlign: TextAlign.center),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  final per = (box.maxWidth / (240 * scale)).floor().clamp(
                    1,
                    3,
                  );
                  final w = (box.maxWidth - 10 * (per - 1)) / per;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final b in shown)
                        SizedBox(
                          width: w,
                          child: Material(
                            color: tokens['raisedSurface'],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: tokens['border']),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('library-${b.id}'),
                              onTap: () => widget.onOpen(b.id),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _bankIcon[b.id] ?? Icons.notes,
                                      size: 32,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name(b.id),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            c('${b.id}.d'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${b.count} ${c('exercises')}'
                                            '${b.done > 0 ? ' · ${c('done')} ${b.done}' : ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
