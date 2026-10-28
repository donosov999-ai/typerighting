import 'package:flutter/material.dart';

import '../design_system/templates.dart';

/// Trainer pieces for B1–B3 (sheet 02-v2-synapse): the exercise bar on top,
/// big live numbers, and options that move into a sheet on narrow screens
/// (DESIGN_TEMPLATE_REF §6: they never just disappear).
String practiceCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'of': ['из', 'of', 'de', 'von', 'sur', 'di', 'de'],
    'exercise': [
      'Упражнение',
      'Exercise',
      'Ejercicio',
      'Übung',
      'Exercice',
      'Esercizio',
      'Exercício',
    ],
    'back': [
      'Назад',
      'Back',
      'Atrás',
      'Zurück',
      'Retour',
      'Indietro',
      'Voltar',
    ],
    'next': [
      'Далее',
      'Next',
      'Siguiente',
      'Weiter',
      'Suivant',
      'Avanti',
      'Seguinte',
    ],
    'options': [
      'Параметры',
      'Options',
      'Opciones',
      'Optionen',
      'Options',
      'Opzioni',
      'Opções',
    ],
    'plain': [
      'Без пунктуации',
      'No punctuation',
      'Sin puntuación',
      'Ohne Satzzeichen',
      'Sans ponctuation',
      'Senza punteggiatura',
      'Sem pontuação',
    ],
    'digits': [
      'Только цифры',
      'Digits only',
      'Solo números',
      'Nur Ziffern',
      'Chiffres seulement',
      'Solo cifre',
      'Só números',
    ],
    'speed': [
      'скорость',
      'speed',
      'velocidad',
      'Tempo',
      'vitesse',
      'velocità',
      'velocidade',
    ],
    'accuracy': [
      'точность',
      'accuracy',
      'precisión',
      'Genauigkeit',
      'précision',
      'precisione',
      'precisão',
    ],
    'errors': [
      'ошибки',
      'errors',
      'errores',
      'Fehler',
      'erreurs',
      'errori',
      'erros',
    ],
    'time': ['время', 'time', 'tiempo', 'Zeit', 'temps', 'tempo', 'tempo'],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

/// «Русские слова ▾ · Упражнение 4 из 22 ▬▬ · ← Назад · Далее →».
class PracticeHeader extends StatelessWidget {
  const PracticeHeader({
    super.key,
    required this.language,
    required this.bankPicker,
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
    this.onOptions,
  });
  final String language;
  final Widget bankPicker;
  final int index, count;
  final VoidCallback? onPrev, onNext;

  /// Narrow screens: the options live in a sheet behind this button.
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    String c(String k) => practiceCopy(language, k);
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens['border']),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Flexible(child: bankPicker),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${c('exercise')} ${index + 1} ${c('of')} $count',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: count == 0 ? 0 : (index + 1) / count,
                  minHeight: 6,
                  backgroundColor: tokens['border'],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onOptions != null)
              IconButton.outlined(
                tooltip: c('options'),
                onPressed: onOptions,
                icon: const Icon(Icons.tune),
              ),
            Tooltip(
              message: 'Предыдущее',
              child: OutlinedButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(c('back')),
              ),
            ),
            Tooltip(
              message: 'Следующее',
              child: FilledButton.icon(
                onPressed: onNext,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(c('next')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Big live numbers: WPM, accuracy, errors, time.
class StatTiles extends StatelessWidget {
  const StatTiles({
    super.key,
    required this.language,
    required this.wpm,
    required this.accuracy,
    required this.errors,
    required this.elapsedMs,
    this.compact = false,
  });
  final String language;
  final num wpm, accuracy;
  final int errors, elapsedMs;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    String c(String k) => practiceCopy(language, k);
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final big = compact ? 20.0 : 30.0;
    Widget cell(String value, String unit, String label) => Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(fontSize: big * .55),
                    ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(fontSize: big, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ],
        ),
      ),
    );
    final divider = Container(width: 1, height: 36, color: tokens['border']);
    final cells = [
      cell('$wpm', '', 'WPM · ${c('speed')}'),
      cell('${accuracy.round()}', '%', c('accuracy')),
      cell('$errors', '', c('errors')),
      cell((elapsedMs / 1000).toStringAsFixed(1), 's', c('time')),
    ];
    return Container(
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens['border']),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          // Four numbers in one row need ~80 px each; otherwise 2 x 2.
          if (box.maxWidth >= 4 * 80 * scale) {
            return Row(
              children: [
                cells[0],
                divider,
                cells[1],
                divider,
                cells[2],
                divider,
                cells[3],
              ],
            );
          }
          return Column(
            children: [
              Row(children: [cells[0], divider, cells[1]]),
              Divider(height: 1, color: tokens['border']),
              Row(children: [cells[2], divider, cells[3]]),
            ],
          );
        },
      ),
    );
  }
}
