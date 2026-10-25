import 'package:flutter/material.dart';

import '../design_system/templates.dart';
import '../domain/today.dart';

String shellText(String language, String key) {
  const copy = <String, List<String>>{
    'today': [
      'Сегодня',
      'Today',
      'Hoy',
      'Heute',
      'Aujourd’hui',
      'Oggi',
      'Hoje',
    ],
    'practice': [
      'Практика',
      'Practice',
      'Práctica',
      'Üben',
      'Pratique',
      'Pratica',
      'Prática',
    ],
    'progress': [
      'Прогресс',
      'Progress',
      'Progreso',
      'Fortschritt',
      'Progrès',
      'Progressi',
      'Progresso',
    ],
    'more': ['Ещё', 'More', 'Más', 'Mehr', 'Plus', 'Altro', 'Mais'],
    'intro': [
      'Небольшая практика — большие результаты!',
      'A little practice, every day.',
      'Un poco de práctica cada día.',
      'Jeden Tag ein wenig üben.',
      'Un peu de pratique chaque jour.',
      'Un po’ di pratica ogni giorno.',
      'Um pouco de prática todos os dias.',
    ],
    'greeting': [
      'Пора потренироваться',
      'Time to practise',
      'Hora de practicar',
      'Zeit zum Üben',
      'C’est le moment de pratiquer',
      'È ora di esercitarsi',
      'Hora de praticar',
    ],
    'hint': [
      'Ещё один шаг к свободной печати.',
      'One more step towards fluent typing.',
      'Un paso más hacia una escritura fluida.',
      'Ein weiterer Schritt zum flüssigen Tippen.',
      'Un pas de plus vers une frappe fluide.',
      'Un altro passo verso una digitazione fluida.',
      'Mais um passo para digitar com fluência.',
    ],
    'start': [
      'Начать тренировку',
      'Start practice',
      'Empezar práctica',
      'Übung starten',
      'Commencer',
      'Inizia a esercitarti',
      'Iniciar prática',
    ],
    'continue': [
      'Продолжить курс',
      'Continue course',
      'Continuar curso',
      'Kurs fortsetzen',
      'Continuer le cours',
      'Continua il corso',
      'Continuar curso',
    ],
    'firstCourse': [
      'Начать курс',
      'Start course',
      'Empezar curso',
      'Kurs beginnen',
      'Commencer le cours',
      'Inizia il corso',
      'Iniciar curso',
    ],
    'review': [
      'Повторить курс',
      'Review course',
      'Repasar curso',
      'Kurs wiederholen',
      'Revoir le cours',
      'Ripassa il corso',
      'Rever curso',
    ],
    'lesson': [
      'Урок',
      'Lesson',
      'Lección',
      'Lektion',
      'Leçon',
      'Lezione',
      'Lição',
    ],
    'streak': [
      'Серия дней',
      'Day streak',
      'Racha de días',
      'Tagesfolge',
      'Série de jours',
      'Giorni consecutivi',
      'Dias seguidos',
    ],
    'last': [
      'Последний результат',
      'Latest result',
      'Último resultado',
      'Letztes Ergebnis',
      'Dernier résultat',
      'Ultimo risultato',
      'Último resultado',
    ],
    'empty': [
      'Пока нет занятий',
      'No sessions yet',
      'Sin sesiones aún',
      'Noch keine Übungen',
      'Aucune séance',
      'Nessuna sessione',
      'Ainda sem sessões',
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
    'choose': [
      'Выберите режим и развивайте навык',
      'Choose a mode and practise',
      'Elige un modo y practica',
      'Modus wählen und üben',
      'Choisissez un mode',
      'Scegli una modalità',
      'Escolha um modo e pratique',
    ],
    'local': [
      'Локальная история на этом устройстве',
      'Local history on this device',
      'Historial local en este dispositivo',
      'Lokaler Verlauf auf diesem Gerät',
      'Historique local sur cet appareil',
      'Cronologia locale su questo dispositivo',
      'Histórico local neste dispositivo',
    ],
  };
  final index = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'].indexOf(language);
  return copy[key]?[index < 0 ? 1 : index] ?? key;
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.summary,
    required this.language,
    required this.lessonTitle,
    required this.onPractice,
    required this.onCourse,
    required this.onProgress,
  });
  final TodaySummary summary;
  final String language, lessonTitle;
  final VoidCallback onPractice, onCourse, onProgress;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final accent = Theme.of(context).colorScheme.primary;
    String t(String k) => shellText(language, k);
    final latest = summary.latest;
    final border = BorderSide(color: tokens['border']);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const ValueKey('today-hero'),
              constraints: const BoxConstraints(minHeight: 166),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.fromBorderSide(border),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xff061521)),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 112,
                    child: Image.asset(
                      'assets/artwork/today-mountains-v1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xeb061521)],
                          stops: [.16, .72],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 47),
                        Text(
                          t('greeting'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t('hint'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xffd7e7ef),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: onPractice,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t('start'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: tokens['surface'],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: border,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('today-course'),
                onTap: onCourse,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xff17bfb1).withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xff27d6c5),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(
                                summary.completed == 0
                                    ? 'firstCourse'
                                    : summary.completed == summary.lessonCount
                                    ? 'review'
                                    : 'continue',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t('lesson')} ${summary.nextLesson}. $lessonTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens['mutedText'],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: summary.progress,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(5),
                                    color: const Color(0xff27d6c5),
                                    backgroundColor: tokens['keyboardBase'],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(summary.progress * 100).round()}%',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.local_fire_department,
                      iconColor: accent,
                      title: t('streak'),
                      value: '${summary.streak}',
                      detail: '',
                      border: border,
                      onTap: onProgress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Metric(
                      icon: Icons.bar_chart,
                      iconColor: const Color(0xff27d6c5),
                      title: t('last'),
                      value: latest == null ? '—' : '${latest['wpm']} WPM',
                      detail: latest == null
                          ? t('empty')
                          : '${t('accuracy')} ${(latest['accuracy'] as num).round()}%',
                      border: border,
                      onTap: onProgress,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.detail,
    required this.border,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title, value, detail;
  final BorderSide border;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: border,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 25),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
