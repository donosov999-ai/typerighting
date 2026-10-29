import 'package:flutter/material.dart';
import 'package:synapse_pet/synapse_pet.dart';

import '../design_system/templates.dart';
import 'common_copy.dart';

/// Exercise result (M3): the real saved numbers, «Новый личный рекорд» only
/// when the source rule confirmed it (positive WPM above the bank's saved
/// best), and Synapse's grounded line after the save (§7). Buttons stay
/// above the pet so they are visible without scrolling.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.language,
    required this.tr,
    required this.profile,
    required this.wpm,
    required this.accuracy,
    required this.errors,
    required this.saved,
    required this.saving,
    required this.record,
    required this.onNext,
    required this.onAgain,
    required this.onRetrySave,
    this.pet,
    this.onSynapse,
    this.wide = false,
  });
  final String language, profile;
  final String Function(String) tr;
  final num wpm, accuracy;
  final int errors;
  final bool saved, saving, record;
  final VoidCallback onNext, onAgain, onRetrySave;

  /// The shared pet showing its line; null when Synapse is off.
  final Widget? pet;
  final VoidCallback? onSynapse;

  /// M3 on a desktop (sheet 13): one card in the main column — big Synapse
  /// on the left, title, three tiles in a row, record and buttons on the right.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    String c(String k) => resultCopy(language, k);
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    Widget tile(
      IconData icon,
      String label,
      String value,
      Color color,
    ) => Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens['border']),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    final tiles = [
      tile(Icons.speed, c('speed'), '$wpm WPM', scheme.primary),
      tile(
        Icons.track_changes,
        c('accuracy'),
        '${accuracy.round()}%',
        tokens['success'],
      ),
      tile(
        Icons.description_outlined,
        c('errors'),
        '$errors',
        errors == 0 ? tokens['success'] : tokens['danger'],
      ),
    ];
    if (wide) {
      final body = _body(context, c, tiles, wideTiles: true);
      return Container(
        key: const ValueKey('result-wide'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens['raisedSurface'],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens['border']),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (saved && pet != null) ...[
              SizedBox(width: 300, height: 340, child: pet),
              const SizedBox(width: 20),
            ],
            Expanded(child: body),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _body(context, c, tiles),
        if (saved && pet != null) ...[
          const SizedBox(height: 8),
          // Pet plus its speech bubble above it (the widget fits both).
          SizedBox(height: 260, child: pet),
        ],
      ],
    );
  }

  Widget _body(
    BuildContext context,
    String Function(String) c,
    List<Widget> tiles, {
    bool wideTiles = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          errors == 0
              ? c('clean')
              : tr(profile == 'f' ? 'done.title.f' : 'done.title'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (wideTiles)
          Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: tiles),
        if (saved && record) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c('record'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        c('record.d'),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (saving)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(commonCopy(language, 'saving')),
              ),
            if (!saved && !saving)
              FilledButton(
                onPressed: onRetrySave,
                child: Text(commonCopy(language, 'retrySave')),
              ),
            if (saved)
              FilledButton(onPressed: onNext, child: Text(tr('done.next'))),
            if (saved)
              OutlinedButton(onPressed: onAgain, child: Text(tr('done.again'))),
            if (saved && onSynapse != null)
              TextButton(onPressed: onSynapse, child: Text(c('synapse'))),
          ],
        ),
      ],
    );
  }
}

String resultCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'clean': [
      'Без единой ошибки!',
      'Not a single mistake!',
      '¡Sin un solo error!',
      'Ohne einen einzigen Fehler!',
      'Sans aucune erreur !',
      'Senza nemmeno un errore!',
      'Sem um único erro!',
    ],
    'speed': [
      'Скорость',
      'Speed',
      'Velocidad',
      'Tempo',
      'Vitesse',
      'Velocità',
      'Velocidade',
    ],
    'accuracy': [
      'Точность',
      'Accuracy',
      'Precisión',
      'Genauigkeit',
      'Précision',
      'Precisione',
      'Precisão',
    ],
    'errors': [
      'Ошибки',
      'Errors',
      'Errores',
      'Fehler',
      'Erreurs',
      'Errori',
      'Erros',
    ],
    'record': [
      'Новый личный рекорд!',
      'New personal best!',
      '¡Nuevo récord personal!',
      'Neue Bestleistung!',
      'Nouveau record personnel !',
      'Nuovo record personale!',
      'Novo recorde pessoal!',
    ],
    'record.d': [
      'Лучшая скорость в этом наборе упражнений.',
      'Your best speed in this exercise set.',
      'Tu mejor velocidad en este conjunto.',
      'Dein bestes Tempo in diesem Übungsset.',
      'Votre meilleure vitesse dans cette série.',
      'La tua velocità migliore in questa serie.',
      'A sua melhor velocidade neste conjunto.',
    ],
    'synapse': [
      'Синапс · мой результат',
      'Synapse · my result',
      'Synapse · mi resultado',
      'Synapse · mein Ergebnis',
      'Synapse · mon résultat',
      'Synapse · il mio risultato',
      'Synapse · o meu resultado',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

/// The pet for the result card, asleep when motion is off.
/// [size] 110 in the narrow pane; the desktop M3 card asks for a big face
/// (sheet 13).
Widget resultPet(
  SynapseController controller,
  bool animate, {
  double size = 110,
}) => TickerMode(
  enabled: animate,
  child: SynapsePet(controller: controller, size: size),
);
