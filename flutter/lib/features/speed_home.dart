import 'package:flutter/material.dart';

import '../design_system/templates.dart';
import '../domain/today.dart';
import 'today_page.dart' show shellText;

/// Home of the `midnight-speed-v1` template (design «Speed / Midnight»,
/// 29.10, DESIGN_REF.md): hero with the main action, quick launch, course,
/// metrics, all modes, weak keys and the week. Entry points only — every
/// action opens an existing page; all numbers come from local history and
/// are «—» when there is none.
class HomeMode {
  const HomeMode(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
}

/// The hero artwork (no text in it): a theme asset, used in both variants.
const speedHeroAsset = 'assets/artwork/hero-speed-v1.jpg';
const _heroShade = Color(0xFF071923);
const _accent = Color(0xFFFF922F);
const _onAccent = Color(0xFF111B24);
const _progress = Color(0xFF19C9C1);

String speedCopy(String language, String key) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = <String, List<String>>{
    'title1': [
      'Печатай',
      'Type',
      'Escribe',
      'Tippe',
      'Tapez',
      'Digita',
      'Digite',
    ],
    'title2': [
      'свободнее',
      'freely',
      'con libertad',
      'freier',
      'librement',
      'liberamente',
      'livremente',
    ],
    'sub': [
      'Развивай скорость, точность и свой стиль печати',
      'Build speed, accuracy and your own typing style',
      'Mejora tu velocidad, precisión y tu propio estilo',
      'Steigere Tempo, Genauigkeit und deinen eigenen Stil',
      'Gagnez en vitesse, en précision et trouvez votre style',
      'Migliora velocità, precisione e il tuo stile',
      'Ganhe velocidade, precisão e o seu próprio estilo',
    ],
    'cta': [
      'Начать печатать',
      'Start typing',
      'Empezar a escribir',
      'Los tippen',
      'Commencer à taper',
      'Inizia a digitare',
      'Começar a digitar',
    ],
    'warmup': [
      'Разминка · 2 минуты',
      'Warm-up · 2 minutes',
      'Calentamiento · 2 minutos',
      'Aufwärmen · 2 Minuten',
      'Échauffement · 2 minutes',
      'Riscaldamento · 2 minuti',
      'Aquecimento · 2 minutos',
    ],
    'warmup.d': [
      'Разогрей пальцы частыми словами',
      'Warm up your fingers on common words',
      'Calienta los dedos con palabras frecuentes',
      'Wärme die Finger mit häufigen Wörtern auf',
      'Échauffez vos doigts avec des mots courants',
      'Scalda le dita con parole frequenti',
      'Aqueça os dedos com palavras frequentes',
    ],
    'warmup.name': [
      'Разминка',
      'Warm-up',
      'Calentamiento',
      'Aufwärmen',
      'Échauffement',
      'Riscaldamento',
      'Aquecimento',
    ],
    'speedTest.name': [
      'Тест скорости',
      'Speed test',
      'Test de velocidad',
      'Tempotest',
      'Test de vitesse',
      'Test di velocità',
      'Teste de velocidade',
    ],
    'min2': [
      '2 минуты',
      '2 minutes',
      '2 minutos',
      '2 Minuten',
      '2 minutes',
      '2 minuti',
      '2 minutos',
    ],
    'min1': [
      '1 минута',
      '1 minute',
      '1 minuto',
      '1 Minute',
      '1 minute',
      '1 minuto',
      '1 minuto',
    ],
    'speedTest': [
      'Тест скорости · 1 минута',
      'Speed test · 1 minute',
      'Test de velocidad · 1 minuto',
      'Tempotest · 1 Minute',
      'Test de vitesse · 1 minute',
      'Test di velocità · 1 minuto',
      'Teste de velocidade · 1 minuto',
    ],
    'speedTest.d': [
      'Узнай свою текущую скорость',
      'Find out your current speed',
      'Descubre tu velocidad actual',
      'Finde dein aktuelles Tempo heraus',
      'Découvrez votre vitesse actuelle',
      'Scopri la tua velocità attuale',
      'Descubra a sua velocidade atual',
    ],
    'custom.d': [
      'Печатай свои материалы',
      'Type your own material',
      'Escribe tu propio material',
      'Tippe deine eigenen Texte',
      'Tapez vos propres textes',
      'Digita i tuoi testi',
      'Digite os seus textos',
    ],
    'startCourse': [
      'Начать курс',
      'Start the course',
      'Empezar el curso',
      'Kurs beginnen',
      'Commencer le cours',
      'Inizia il corso',
      'Começar o curso',
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
      'Скорость',
      'Speed',
      'Velocidad',
      'Tempo',
      'Vitesse',
      'Velocità',
      'Velocidade',
    ],
    'streak': [
      'Серия',
      'Streak',
      'Racha',
      'Serie',
      'Série',
      'Serie',
      'Sequência',
    ],
    'days': ['дн.', 'days', 'días', 'Tage', 'jours', 'giorni', 'dias'],
    'none': [
      'Пока нет занятий',
      'No sessions yet',
      'Aún no hay sesiones',
      'Noch keine Übungen',
      'Pas encore de séance',
      'Ancora nessuna sessione',
      'Ainda sem sessões',
    ],
    'modes': [
      'Все режимы',
      'All modes',
      'Todos los modos',
      'Alle Modi',
      'Tous les modes',
      'Tutte le modalità',
      'Todos os modos',
    ],
    'weak': [
      'Что потренировать',
      'What to practise',
      'Qué practicar',
      'Was üben',
      'Quoi travailler',
      'Cosa allenare',
      'O que praticar',
    ],
    'weak.d': [
      'Клавиши, на которых вы медленнее или чаще ошибаетесь',
      'Keys where you are slower or make more mistakes',
      'Teclas en las que eres más lento o fallas más',
      'Tasten, bei denen du langsamer bist oder öfter danebenliegst',
      'Touches où vous êtes plus lent ou faites plus d’erreurs',
      'Tasti su cui sei più lento o sbagli di più',
      'Teclas em que você é mais lento ou erra mais',
    ],
    'weak.go': [
      'Тренировать',
      'Practise',
      'Practicar',
      'Üben',
      'S’entraîner',
      'Allenati',
      'Praticar',
    ],
    'weak.none': [
      'Пока мало данных о клавишах. Пройдите тест скорости.',
      'Not enough key data yet. Take the speed test.',
      'Aún faltan datos de teclas. Haz el test de velocidad.',
      'Noch zu wenig Tastendaten. Mach den Tempotest.',
      'Pas encore assez de données. Faites le test de vitesse.',
      'Dati sui tasti insufficienti. Fai il test di velocità.',
      'Ainda faltam dados das teclas. Faça o teste de velocidade.',
    ],
    'week': [
      'Прогресс за неделю',
      'This week',
      'Esta semana',
      'Diese Woche',
      'Cette semaine',
      'Questa settimana',
      'Esta semana',
    ],
  };
  final i = langs.indexOf(language);
  return words[key]?[i < 0 ? 1 : i] ?? key;
}

class SpeedHome extends StatelessWidget {
  const SpeedHome({
    super.key,
    required this.language,
    required this.summary,
    required this.lessonTitle,
    required this.modes,
    required this.weakKeys,
    required this.week,
    required this.customTitle,
    required this.onStart,
    required this.onWarmup,
    required this.onSpeedTest,
    required this.onCustomText,
    required this.onCourse,
    required this.onWeak,
    required this.onProgress,
    this.migrationNotice,
  });
  final String language, lessonTitle, customTitle;
  final Widget? migrationNotice;
  final TodaySummary summary;
  final List<HomeMode> modes;

  /// Up to three weakest letters from the key statistics; empty = no data.
  final List<String> weakKeys;

  /// Average WPM per day, oldest first, seven days ending today; null = none.
  final List<double?> week;
  final VoidCallback onStart,
      onWarmup,
      onSpeedTest,
      onCustomText,
      onCourse,
      onWeak,
      onProgress;

  String t(String k) => speedCopy(language, k);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final wide = w >= 1024, mid = w >= 600;
      final compactQuick =
          !mid && w >= 350 && MediaQuery.textScalerOf(context).scale(1) <= 1.2;
      final gap = mid ? 16.0 : 12.0;
      final quick = [
        _QuickCard(
          key: const ValueKey('home-warmup'),
          icon: Icons.local_fire_department_outlined,
          title: t('warmup'),
          subtitle: t('warmup.d'),
          compact: compactQuick,
          short: t('warmup.name'),
          shortNote: t('min2'),
          onTap: onWarmup,
        ),
        _QuickCard(
          key: const ValueKey('home-speed-test'),
          icon: Icons.timer_outlined,
          title: t('speedTest'),
          subtitle: t('speedTest.d'),
          compact: compactQuick,
          short: t('speedTest.name'),
          shortNote: t('min1'),
          onTap: onSpeedTest,
        ),
        _QuickCard(
          key: const ValueKey('home-custom-text'),
          icon: Icons.description_outlined,
          title: customTitle,
          subtitle: t('custom.d'),
          compact: compactQuick,
          short: customTitle,
          onTap: onCustomText,
        ),
      ];
      final metrics = [
        _Metric(
          icon: Icons.track_changes,
          label: t('accuracy'),
          value: summary.latest == null ? '—' : '${summary.latest!['acc']}%',
        ),
        _Metric(
          icon: Icons.bolt,
          label: t('speed'),
          value: summary.latest == null ? '—' : '${summary.latest!['wpm']} WPM',
        ),
        if (wide)
          _Metric(
            icon: Icons.local_fire_department_outlined,
            label: t('streak'),
            value: summary.streak == 0 ? '—' : '${summary.streak} ${t('days')}',
          ),
      ];
      final course = _CourseCard(
        title: summary.completed == 0
            ? t('startCourse')
            : shellText(language, 'continue'),
        lesson: '${t('lesson')} ${summary.nextLesson} · $lessonTitle',
        progress: summary.progress,
        onTap: onCourse,
      );
      final columns = wide ? 4 : (w >= 720 ? 3 : 2);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(
                height: wide ? 280 : 260,
                title1: t('title1'),
                title2: t('title2'),
                subtitle: t('sub'),
                cta: t('cta'),
                onStart: onStart,
              ),
              if (migrationNotice != null) ...[
                SizedBox(height: gap),
                migrationNotice!,
              ],
              SizedBox(height: gap),
              if (compactQuick)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, q) in quick.indexed) ...[
                        if (i > 0) SizedBox(width: gap),
                        Expanded(child: q),
                      ],
                    ],
                  ),
                )
              else
                _Wrap(
                  columns: wide ? 3 : (mid ? 2 : 1),
                  minWidth: 220,
                  gap: gap,
                  children: quick,
                ),
              SizedBox(height: gap),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: course),
                    for (final m in metrics) ...[
                      SizedBox(width: gap),
                      Expanded(flex: 2, child: m),
                    ],
                  ],
                )
              else ...[
                course,
                SizedBox(height: gap),
                Row(
                  children: [
                    for (final (i, m) in metrics.indexed) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(child: m),
                    ],
                  ],
                ),
              ],
              SizedBox(height: gap * 1.5),
              Text(t('modes'), style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: gap),
              _Wrap(
                columns: columns,
                minWidth: 160,
                gap: gap,
                children: [
                  for (final m in modes)
                    _ModeCard(mode: m, key: ValueKey('home-mode-${m.title}')),
                ],
              ),
              SizedBox(height: gap * 1.5),
              _Wrap(
                columns: mid ? 2 : 1,
                minWidth: 280,
                gap: gap,
                children: [
                  _WeakCard(
                    title: t('weak'),
                    subtitle: weakKeys.isEmpty ? t('weak.none') : t('weak.d'),
                    keys: weakKeys,
                    action: weakKeys.isEmpty ? t('speedTest') : t('weak.go'),
                    onTap: weakKeys.isEmpty ? onSpeedTest : onWeak,
                  ),
                  _WeekCard(
                    title: t('week'),
                    empty: t('none'),
                    week: week,
                    onTap: onProgress,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Equal-width cards in [columns] columns that drop to fewer columns when a
/// card would be narrower than [minWidth] (large text, narrow window).
class _Wrap extends StatelessWidget {
  const _Wrap({
    required this.columns,
    required this.minWidth,
    required this.gap,
    required this.children,
  });
  final int columns;
  final double minWidth, gap;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      var n = columns;
      while (n > 1 && (box.maxWidth - gap * (n - 1)) / n < minWidth) {
        n--;
      }
      final width = (box.maxWidth - gap * (n - 1)) / n;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: width, child: c)],
      );
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.padding = 16});
  final Widget child;
  final VoidCallback? onTap;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Material(
      color: tokens['surface'],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens['border']),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.height,
    required this.title1,
    required this.title2,
    required this.subtitle,
    required this.cta,
    required this.onStart,
  });
  final double height;
  final String title1, title2, subtitle, cta;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Phone: the artwork is fitted to the width and pinned to the top, so the
    // keys sit above the text and the two-line title lands on the dark lower
    // part of the picture (the mockup), not on the lit keys (snapshot 04.11).
    final narrow = MediaQuery.sizeOf(context).width < 600;
    // Both theme variants keep the dark header with white text (ref §2).
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(minHeight: height * scale.clamp(1, 1.6)),
        decoration: BoxDecoration(
          color: _heroShade,
          image: DecorationImage(
            image: const AssetImage(speedHeroAsset),
            fit: narrow ? BoxFit.fitWidth : BoxFit.cover,
            alignment: narrow ? Alignment.topRight : Alignment.centerRight,
          ),
        ),
        foregroundDecoration: null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: narrow ? Alignment.bottomCenter : Alignment.bottomLeft,
              end: narrow ? Alignment.topCenter : Alignment.topRight,
              colors: [
                _heroShade.withValues(alpha: narrow ? 1 : .92),
                _heroShade.withValues(alpha: narrow ? .9 : .55),
                _heroShade.withValues(alpha: 0),
              ],
              // Phone: opaque under the text, hides the artwork's lower edge.
              stops: narrow ? const [0, .45, .75] : const [0, .5, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, narrow ? 150 : 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: narrow ? '$title1\n' : '$title1 '),
                        TextSpan(
                          text: title2,
                          style: const TextStyle(color: _accent),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDCE7EE),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('home-start'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _onAccent,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onStart,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(cta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
    this.short,
    this.shortNote = '',
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool compact;

  /// Phone row (mockup): a short name and the duration instead of the full
  /// title and description, so three cards stay readable side by side.
  final String? short;
  final String shortNote;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<TypeFreeTokens>()!['mutedText'];
    if (compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: _Card(
          onTap: onTap,
          padding: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                short ?? title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      short == null ? subtitle : shortNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ),
                  if (short != null)
                    Icon(Icons.chevron_right, size: 16, color: muted),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(subtitle, style: TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.lesson,
    required this.progress,
    required this.onTap,
  });
  final String title, lesson;
  final double progress;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const ValueKey('home-course-title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(lesson, style: TextStyle(color: tokens['mutedText'])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: _progress,
                          backgroundColor: tokens['raisedSurface'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(progress * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tokens['mutedText']),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<TypeFreeTokens>()!['mutedText'];
    return _Card(
      child: Row(
        children: [
          Icon(icon, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: muted, fontSize: 13)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({super.key, required this.mode});
  final HomeMode mode;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<TypeFreeTokens>()!['mutedText'];
    return _Card(
      onTap: mode.onTap,
      padding: 14,
      child: Row(
        children: [
          Icon(
            mode.icon,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  mode.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }
}

class _WeakCard extends StatelessWidget {
  const _WeakCard({
    required this.title,
    required this.subtitle,
    required this.keys,
    required this.action,
    required this.onTap,
  });
  final String title, subtitle, action;
  final List<String> keys;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(subtitle, style: TextStyle(color: tokens['mutedText'])),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final k in keys)
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens['raisedSurface'],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens['border']),
                  ),
                  child: Text(
                    k.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'PTMono',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              FilledButton(
                key: const ValueKey('home-weak'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _onAccent,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onTap,
                child: Text(action),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.title,
    required this.empty,
    required this.week,
    required this.onTap,
  });
  final String title, empty;
  final List<double?> week;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final values = week.whereType<double>();
    final top = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final today = DateTime.now();
    return _Card(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (values.isNotEmpty)
                Text(
                  '${values.last.round()} WPM',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              Icon(Icons.chevron_right, color: tokens['mutedText']),
            ],
          ),
          const SizedBox(height: 12),
          if (values.isEmpty)
            Text(empty, style: TextStyle(color: tokens['mutedText']))
          else
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, v) in week.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: v == null ? 2 : 4 + 64 * v / top,
                              decoration: BoxDecoration(
                                color: v == null ? tokens['border'] : _progress,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${today.subtract(Duration(days: 6 - i)).day}',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens['mutedText'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
