import 'package:flutter/material.dart';
import 'package:synapse_pet/synapse_pet.dart';

import '../design_system/templates.dart';

/// «Синапс» panel (M2, DESIGN_TEMPLATE_REF §7): own progress, the last saved
/// session as a fact, the suitable action «Слабые клавиши», and the shared
/// pet with its lines. Desktop shows it beside the content, phones as a sheet;
/// both have Close. No numbers are invented: no data → «начните тренировку».
class SynapsePanel extends StatefulWidget {
  const SynapsePanel({
    super.key,
    required this.language,
    required this.tr,
    required this.history,
    required this.controller,
    required this.portrait,
    required this.animate,
    required this.onWeak,
    required this.onClose,
  });
  final String language;
  final String Function(String) tr;
  final List<Map<String, dynamic>> history;
  final SynapseController controller;
  final Widget portrait;
  final bool animate;
  final VoidCallback onWeak, onClose;
  @override
  State<SynapsePanel> createState() => _SynapsePanelState();
}

String synapseCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'tagline': [
      'Всегда рядом, чтобы помочь печатать лучше',
      'Always here to help you type better',
      'Siempre aquí para ayudarte a escribir mejor',
      'Immer da, damit du besser tippst',
      'Toujours là pour vous aider à mieux taper',
      'Sempre qui per aiutarti a scrivere meglio',
      'Sempre aqui para ajudar a escrever melhor',
    ],
    'progress': [
      'Мой прогресс',
      'My progress',
      'Mi progreso',
      'Mein Fortschritt',
      'Mes progrès',
      'I miei progressi',
      'O meu progresso',
    ],
    'hints': [
      'Подсказки',
      'Hints',
      'Consejos',
      'Tipps',
      'Conseils',
      'Suggerimenti',
      'Dicas',
    ],
    'next': [
      'Следующее действие',
      'Next step',
      'Siguiente paso',
      'Nächster Schritt',
      'Étape suivante',
      'Prossimo passo',
      'Próximo passo',
    ],
    'weak': [
      'Потренировать слабые клавиши',
      'Practise weak keys',
      'Practicar teclas débiles',
      'Schwache Tasten üben',
      'Travailler les touches faibles',
      'Allenare i tasti deboli',
      'Treinar teclas fracas',
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
    'speed': [
      'Время и скорость',
      'Time and speed',
      'Tiempo y velocidad',
      'Zeit und Tempo',
      'Temps et vitesse',
      'Tempo e velocità',
      'Tempo e velocidade',
    ],
    'last': [
      'на последней тренировке',
      'in the last session',
      'en la última sesión',
      'in der letzten Sitzung',
      'à la dernière séance',
      'nell’ultima sessione',
      'na última sessão',
    ],
    'noData': [
      'Нет данных — начните тренировку',
      'No data yet — start a session',
      'Sin datos: empieza una sesión',
      'Noch keine Daten – starte eine Sitzung',
      'Pas de données — commencez une séance',
      'Nessun dato: inizia una sessione',
      'Sem dados — comece uma sessão',
    ],
    'sessions': [
      'Сохранено тренировок',
      'Saved sessions',
      'Sesiones guardadas',
      'Gespeicherte Sitzungen',
      'Séances enregistrées',
      'Sessioni salvate',
      'Sessões guardadas',
    ],
    'quiet': [
      'Синапс заговорит после сохранённой тренировки — по её настоящим цифрам.',
      'Synapse speaks after a saved session, about its real numbers.',
      'Synapse habla tras una sesión guardada, con sus cifras reales.',
      'Synapse meldet sich nach einer gespeicherten Sitzung – mit echten Zahlen.',
      'Synapse parle après une séance enregistrée, avec ses vrais chiffres.',
      'Synapse parla dopo una sessione salvata, con i numeri reali.',
      'A Synapse fala após uma sessão guardada, com os números reais.',
    ],
    'close': [
      'Закрыть',
      'Close',
      'Cerrar',
      'Schließen',
      'Fermer',
      'Chiudi',
      'Fechar',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class _SynapsePanelState extends State<SynapsePanel> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    String c(String k) => synapseCopy(widget.language, k);
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = scheme.onSurfaceVariant;
    final last = widget.history.isEmpty ? null : widget.history.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 64, height: 64, child: widget.portrait),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Синапс',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(c('tagline'), style: TextStyle(color: muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: c('close'),
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(c('progress'))),
            ButtonSegment(value: 1, label: Text(c('hints'))),
          ],
          selected: {tab},
          onSelectionChanged: (s) => setState(() => tab = s.first),
        ),
        const SizedBox(height: 12),
        if (tab == 0) ...[
          Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onWeak,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.track_changes, color: scheme.onPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c('next').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onPrimary,
                            ),
                          ),
                          Text(
                            c('weak'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onPrimary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final two = box.maxWidth >= 2 * 140 * scale;
              final w = two ? (box.maxWidth - 8) / 2 : box.maxWidth;
              Widget tile(IconData icon, String title, Widget body) => SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens['raisedSurface'],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens['border']),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: tokens['success']),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      body,
                    ],
                  ),
                ),
              );
              final none = Text(
                c('noData'),
                style: TextStyle(fontSize: 12.5, color: muted),
              );
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  tile(
                    Icons.bar_chart,
                    c('accuracy'),
                    last == null
                        ? none
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(last['accuracy'] as num).round()}%',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: tokens['success'],
                                ),
                              ),
                              Text(
                                c('last'),
                                style: TextStyle(fontSize: 11.5, color: muted),
                              ),
                            ],
                          ),
                  ),
                  tile(
                    Icons.schedule,
                    c('speed'),
                    last == null
                        ? none
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${last['wpm']} WPM',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${((last['elapsedMs'] as num) / 1000).toStringAsFixed(1)} s · ${c('last')}',
                                style: TextStyle(fontSize: 11.5, color: muted),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${c('sessions')}: ${widget.history.length}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ] else ...[
          TickerMode(
            enabled: widget.animate,
            child: SynapsePet(controller: widget.controller, size: 170),
          ),
          if (widget.controller.current == null)
            Text(c('quiet'), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
