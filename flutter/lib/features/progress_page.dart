import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/artifact_export.dart';
import '../data/local_repository.dart';
import '../data/legacy_transfer.dart';
import '../data/progress_view.dart';
import '../data/achievement_store.dart';
import '../domain/progress_metrics.dart';
import '../domain/session_context.dart';
import '../design_system/templates.dart';
import 'profile_page.dart' show languageNames;

class ProgressPage extends StatefulWidget {
  const ProgressPage({
    super.key,
    required this.repository,
    required this.profile,
    required this.language,
    required this.tr,
    required this.onWeak,
    this.onAchievements,
    this.exporter,
    this.clock,
    this.migrationPending = false,
  });
  final LocalRepository repository;
  final String profile, language;
  final String Function(String) tr;
  final VoidCallback onWeak;
  final VoidCallback? onAchievements;
  final ArtifactExporter? exporter;
  final int Function()? clock;
  final bool migrationPending;
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final target = TextEditingController();
  String? series, status, recoveryStatus;

  /// F1 «7 дней» of sheet 06: days shown in the chart (0 = all time);
  /// null until the user picks one.
  int? period;
  int visibleSessions = 20;
  bool saving = false;
  int now() => widget.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
  @override
  void initState() {
    super.initState();
    target.text = '${targetValue()}';
  }

  int targetValue() {
    final raw = (widget.repository.data['legacy'] as Map)['tr_target_wpm'];
    final value = raw is String ? num.tryParse(raw) : null;
    return value != null && value.isFinite && value > 0 ? value.round() : 40;
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProgressPage old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile || old.language != widget.language)
      series = null;
  }

  Future<void> saveTarget() async {
    final value = int.tryParse(target.text);
    if (value == null || value < 1 || !value.toDouble().isFinite) {
      setState(() => status = copy('invalid'));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.transaction((d) {
        (d['legacy'] as Map)['tr_target_wpm'] = '$value';
      });
      if (mounted) setState(() => status = copy('saved'));
    } catch (_) {
      if (mounted) setState(() => status = copy('failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> export() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final result = await exportHistory(
        widget.repository,
        widget.exporter,
        now(),
      );
      if (mounted)
        setState(
          () => status = copy(
            result == ArtifactExportOutcome.cancelled
                ? 'cancelled'
                : result == ArtifactExportOutcome.requested
                ? 'requested'
                : 'saved',
          ),
        );
    } catch (_) {
      if (mounted) setState(() => status = copy('failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> exportRecovery(String id, Map values) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final envelope = createTransfer(
        Map<String, String>.from(values),
        exportId: 'recovery-$id',
      );
      final result = await (widget.exporter ?? saveArtifact)(
        'TypeFree-recovery-${id.substring(0, 12)}.json',
        Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        'application/json',
      );
      if (mounted)
        setState(
          () => recoveryStatus = copy(
            result == ArtifactExportOutcome.cancelled
                ? 'cancelled'
                : result == ArtifactExportOutcome.requested
                ? 'requested'
                : 'saved',
          ),
        );
    } catch (_) {
      if (mounted) setState(() => recoveryStatus = copy('failed'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String copy(String key) => progressCopy(widget.language, key);
  @override
  Widget build(BuildContext context) {
    final view = ProgressView(widget.repository.data), rows = view.timeline;
    final pending = (widget.repository.data['webviewPending'] as Map?) ?? {};
    final recoveryEntries = pending.entries.toList();
    final invalidKeys =
        (widget.repository.data['prefs'] as Map)['webviewInvalidKeys'];
    final pendingHistories = [
      for (final entry in pending.entries)
        if (entry.value is Map && (entry.value as Map)['tr_history'] is String)
          jsonDecode((entry.value as Map)['tr_history'] as String) as List,
    ];
    final known = rows
        .where(
          (r) =>
              r['origin'] == 'flutter' &&
              r['profile'] == widget.profile &&
              r['language'] == widget.language &&
              sessionSeriesKey(r) != null,
        )
        .toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in known) {
      groups.putIfAbsent(sessionSeriesKey(row)!, () => []).add(row);
    }
    if (!groups.containsKey(series)) series = groups.keys.firstOrNull;
    final selected = groups[series] ?? [];
    final ordered = List<Map<String, dynamic>>.from(selected)
      ..sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
    final speeds = ordered.map((r) => r['wpm'] as num).toList();
    final forecast = speedForecast(speeds, targetValue());
    final earned = view.achievements.toSet();
    final eligible = eligibleAchievementIds(
      widget.repository.data,
      now(),
    ).toSet();
    final allEarned = {...earned, ...eligible};
    final eligibleRows = rows
        .where((r) => r['historyEligible'] != false)
        .toList();
    final stamps = eligibleRows.map((r) => r['t'] as num);
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    final muted = scheme.onSurfaceVariant;
    // Period as on sheet 06 («7 дней»); with fewer than two sessions in the
    // last 7 days the default falls back to all time, never an empty chart.
    const day = 86400000;
    List<Map<String, dynamic>> within(int days) => days == 0
        ? ordered
        : ordered.where((r) => (r['t'] as num) >= now() - days * day).toList();
    final shown = period ?? (within(7).length >= 2 ? 7 : 0);
    final window = within(shown);
    final recent = window.skip(max(0, window.length - 40)).toList();
    final shownSpeeds = recent.map((r) => r['wpm'] as num).toList();
    final titles = <String, int>{};
    for (final g in groups.values) {
      final t = g.first['title'] as String;
      titles[t] = (titles[t] ?? 0) + 1;
    }
    String seriesLabel(String key) {
      final first = groups[key]!.first;
      final t = first['title'] as String;
      // Same exercise in two set-ups (layout, hidden text…): keep them apart.
      return titles[t]! > 1 ? '$t · ${first['difficulty']}' : t;
    }

    final best = eligibleRows.fold<num>(0, (n, r) => max(n, r['wpm'] as num));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy('local'), style: TextStyle(color: muted)),
        if (widget.migrationPending)
          _Panel(
            child: Text(
              copy('migrationPending'),
              key: const ValueKey('progress-migration-pending'),
            ),
          ),
        if (invalidKeys is List && invalidKeys.isNotEmpty)
          _Panel(
            child: Text(
              copy('recoveryInvalid'),
              key: const ValueKey('progress-recovery-invalid'),
            ),
          ),
        if (pending.isNotEmpty)
          _Panel(
            child: Material(
              color: Colors.transparent,
              child: ExpansionTile(
                key: const ValueKey('progress-recovery'),
                title: Text(copy('recoveryTitle')),
                subtitle: Text(copy('recoveryHint')),
                children: [
                  for (var i = 0; i < recoveryEntries.length; i++)
                    OutlinedButton.icon(
                      key: ValueKey('recovery-export-$i'),
                      onPressed: saving
                          ? null
                          : () => exportRecovery(
                              recoveryEntries[i].key as String,
                              recoveryEntries[i].value as Map,
                            ),
                      icon: const Icon(Icons.download_outlined),
                      label: Text('${copy('recoverySave')} ${i + 1}'),
                    ),
                  Text(copy('recoverySaveHint'), textAlign: TextAlign.center),
                  if (recoveryStatus != null)
                    Text(
                      recoveryStatus!,
                      key: const ValueKey('recovery-export-status'),
                    ),
                  for (var i = 0; i < pendingHistories.length; i++)
                    ExpansionTile(
                      title: Text(
                        '${copy('recoveryCopy')} ${i + 1} · ${pendingHistories[i].length}',
                      ),
                      children: [
                        for (final row in pendingHistories[i])
                          _SessionRow(
                            title: copy('oldSession'),
                            when: _when((row as Map)['t'] as num),
                            detail: '',
                            wpm: row['wpm'] as num,
                            accuracy: normalAccuracy(row['acc'] as num),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    copy('yours'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (groups.length > 1)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('progress-series-$series'),
                        initialValue: series,
                        isExpanded: true,
                        isDense: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          for (final key in groups.keys)
                            DropdownMenuItem(
                              value: key,
                              child: Text(
                                seriesLabel(key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => series = v),
                      ),
                    )
                  else if (series != null)
                    Text(seriesLabel(series!), style: TextStyle(color: muted)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: DropdownButton<int>(
                      key: const ValueKey('progress-period'),
                      value: shown,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        for (final (d, k) in [
                          (7, 'days7'),
                          (30, 'days30'),
                          (0, 'allTime'),
                        ])
                          DropdownMenuItem(
                            value: d,
                            child: Text(
                              copy(k),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => period = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                copy('seriesHint'),
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
              if (shownSpeeds.length >= 2) ...[
                const SizedBox(height: 12),
                Semantics(
                  key: const ValueKey('progress-chart-summary'),
                  label: recent
                      .map(
                        (r) =>
                            '${_when(r['t'] as num)}: ${copy('speed')} ${r['wpm']} WPM, ${copy('acc')} ${(r['accuracy'] as num).round()}%',
                      )
                      .join('; '),
                  child: SizedBox(
                    key: const ValueKey('progress-chart'),
                    height:
                        MediaQuery.sizeOf(context).width < 600 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 16.8
                        ? 132
                        : max(
                            170,
                            MediaQuery.textScalerOf(context).scale(10) * 8 + 40,
                          ),
                    child: CustomPaint(
                      painter: _DualChart(
                        speeds: [for (final r in recent) r['wpm'] as num],
                        accuracy: [
                          for (final r in recent) r['accuracy'] as num,
                        ],
                        dates: [for (final r in recent) r['t'] as num],
                        speedColor: scheme.primary,
                        accuracyColor: tokens['success'],
                        grid: tokens['border'],
                        label: muted,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Legend(scheme.primary, copy('speed')),
                    _Legend(tokens['success'], copy('acc')),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.tr('prog.sessions')}: ${shownSpeeds.length} · ${widget.tr('prog.max')}: ${shownSpeeds.reduce(max)} WPM · ${widget.tr('prog.last')}: ${shownSpeeds.last} WPM',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(widget.tr('prog.empty')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final tiles = [
              _Stat(
                Icons.local_fire_department,
                const Color(0xFFF07B2B),
                '${utcStreak(stamps, now())}',
                widget.tr('hub.streak'),
                key: const ValueKey('progress-stat-streak'),
              ),
              _Stat(
                Icons.schedule,
                const Color(0xFF14A3A3),
                '${eligibleRows.length}',
                widget.tr('prog.sessions'),
                key: const ValueKey('progress-stat-sessions'),
              ),
              _Stat(
                Icons.bar_chart,
                const Color(0xFF22B07D),
                '$best',
                copy('best'),
                key: const ValueKey('progress-stat-best'),
              ),
            ];
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final per = box.maxWidth >= 3 * 104 * scale ? 3 : 1;
            const gap = 8.0;
            if (per == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(height: gap),
                    tiles[i],
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '${copy('course')}: ${view.courseStars} · ${copy('kids')}: ${view.kidsStars}',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        // Sheet 06 order: chart → tiles → recent sessions, then the extras.
        const SizedBox(height: 16),
        Text(
          copy('recent'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (view.legacyTimeline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              copy('unknown'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          _Panel(
            child: Column(
              children: [
                Icon(Icons.description_outlined, color: muted, size: 32),
                const SizedBox(height: 6),
                Text(copy('noSessions'), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          _Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < min(rows.length, visibleSessions); i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 52),
                  _SessionRow(
                    title: rows[i]['origin'] == 'legacy'
                        ? copy('oldSession')
                        : rows[i]['title'] as String,
                    when: _when(rows[i]['t'] as num),
                    detail: rows[i]['origin'] == 'flutter'
                        ? [
                            ['m', 'f', 'kids'].contains(rows[i]['profile'])
                                ? widget.tr('profile.${rows[i]['profile']}')
                                : rows[i]['profile'],
                            languageNames[rows[i]['language']] ??
                                rows[i]['language'],
                            progressModeLabel(
                              widget.language,
                              rows[i]['mode'] as String,
                            ),
                          ].join(' · ')
                        : '',
                    wpm: rows[i]['wpm'] as num,
                    accuracy: rows[i]['accuracy'] as num,
                  ),
                ],
                if (rows.length > visibleSessions)
                  TextButton(
                    key: const ValueKey('progress-show-more'),
                    onPressed: () => setState(() => visibleSessions += 20),
                    child: Text(copy('showMore')),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onWeak,
              icon: const Icon(Icons.track_changes),
              label: Text(widget.tr('weak.title')),
            ),
            OutlinedButton.icon(
              onPressed: widget.onAchievements,
              icon: const Icon(Icons.emoji_events_outlined),
              label: Text(
                '${widget.tr('ach.title')} · ${milestones.where((b) => allEarned.contains(b.id)).length}/${milestones.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('progress-target'),
                controller: target,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: widget.tr('set.targetwpm'),
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: saving ? null : saveTarget,
                    child: Text(copy('saveTarget')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                forecast == null
                    ? copy('noForecast')
                    : '${widget.tr('prog.to')} ${forecast.target} WPM ≈ ${forecast.sessions} ${widget.tr('prog.sess')} · R² ${forecast.certainty.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving ? null : export,
          icon: const Icon(Icons.download_outlined),
          label: Text(copy('export')),
        ),
        if (status != null)
          Text(status!, key: const ValueKey('progress-status')),
        if (saving) const LinearProgressIndicator(),
        if (view.banks.isNotEmpty)
          ExpansionTile(
            title: Text(copy('banks')),
            children: [
              for (final e in view.banks.entries)
                ListTile(
                  title: Text(e.key),
                  subtitle: Text(
                    '${copy('completed')}: ${(e.value['done'] as List).length} · ${e.value['bestWpm']} WPM · ${e.value['bestAcc']}%',
                  ),
                ),
            ],
          ),
        if (earned.any((id) => !milestones.any((b) => b.id == id)))
          Text(
            '${copy('archivedBadges')}: ${earned.where((id) => !milestones.any((b) => b.id == id)).join(', ')}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
      ],
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
String _when(num t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t.toInt()).toLocal();
  return '${_two(d.day)}.${_two(d.month)}.${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens['raisedSurface'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens['border']),
      ),
      child: child,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.color, this.value, this.label, {super.key});
  final IconData icon;
  final Color color;
  final String value, label;
  @override
  Widget build(BuildContext context) => _Panel(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.title,
    required this.when,
    required this.detail,
    required this.wpm,
    required this.accuracy,
  });
  final String title, when, detail;
  final num wpm, accuracy;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail.isEmpty ? when : '$when · $detail',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$wpm WPM',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${accuracy.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Speed (left axis, WPM) and accuracy (right axis, 0–100 %) of one
/// comparable series, as on sheet 06 F1.
class _DualChart extends CustomPainter {
  _DualChart({
    required this.speeds,
    required this.accuracy,
    required this.dates,
    required this.speedColor,
    required this.accuracyColor,
    required this.grid,
    required this.label,
    required this.textScaler,
  });
  final List<num> speeds, accuracy, dates;
  final Color speedColor, accuracyColor, grid, label;
  final TextScaler textScaler;

  TextPainter _label(String s) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: 10, color: label),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  void _text(Canvas canvas, String s, Offset at, {bool right = false}) {
    final tp = _label(s);
    tp.paint(canvas, at - Offset(right ? tp.width : 0, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (speeds.length < 2) return;
    // Round steps (5, 10, 15…) so the left scale reads like the sketch.
    final top0 = speeds.reduce(max), bottom0 = speeds.reduce(min);
    var step = max(5, ((top0 - bottom0) / 4 / 5).ceil() * 5);
    var lo = (bottom0 / step).floor() * step;
    while (lo + 4 * step < top0) {
      step += 5;
      lo = (bottom0 / step).floor() * step;
    }
    final hi = lo + 4 * step;
    final span = hi - lo;
    final left = max(30.0, max(_label('$hi').width, _label('$lo').width) + 8);
    final right = max(34.0, _label('100').width + 8);
    final top = max(8.0, _label('100').height / 2);
    final bottom = max(20.0, _label('00.00').height + 6);
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _text(
        canvas,
        '${(hi - span * i / 4).round()}',
        Offset(left - 4, y),
        right: true,
      );
      _text(canvas, '${100 - 25 * i}', Offset(left + w + 4, y));
    }
    double x(int i) => left + i / (speeds.length - 1) * w;
    void line(List<num> v, double Function(num) y, Color color) {
      final path = Path();
      for (var i = 0; i < v.length; i++) {
        final p = Offset(x(i), y(v[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        canvas.drawCircle(p, 3, Paint()..color = color);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    line(accuracy, (a) => top + h * (1 - a.clamp(0, 100) / 100), accuracyColor);
    line(speeds, (s) => top + h * (1 - (s - lo) / span), speedColor);
    final marks = {0, (speeds.length - 1) ~/ 2, speeds.length - 1};
    var lastEnd = double.negativeInfinity;
    for (final i in marks) {
      final d = DateTime.fromMillisecondsSinceEpoch(dates[i].toInt()).toLocal();
      final tp = _label('${_two(d.day)}.${_two(d.month)}');
      if (tp.width > size.width) continue;
      final cx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      if (cx < lastEnd + 4) continue;
      tp.paint(canvas, Offset(cx, size.height - tp.height));
      lastEnd = cx + tp.width;
    }
  }

  @override
  bool shouldRepaint(covariant _DualChart old) =>
      old.speeds != speeds ||
      old.accuracy != accuracy ||
      old.dates != dates ||
      old.speedColor != speedColor ||
      old.accuracyColor != accuracyColor ||
      old.grid != grid ||
      old.label != label ||
      old.textScaler != textScaler;
}

/// Explicit export of local history only: no credentials, preferences,
/// teacher permissions, names or private source texts. Used by «Прогресс»
/// and «Данные и разрешения» (F6).
Future<ArtifactExportOutcome> exportHistory(
  LocalRepository repository,
  ArtifactExporter? exporter,
  int now,
) {
  final document = repository.data;
  final rows = ProgressView(document).timeline;
  final pending = (document['webviewPending'] as Map?) ?? {};
  // Recovery copies may overlap the timeline or one another. Keep them in a
  // separate field so an export cannot silently count them as new sessions.
  // Other pending values include preferences and are deliberately excluded.
  final recoveryHistories = [
    for (final snapshot in pending.values)
      if (snapshot is Map && snapshot['tr_history'] is String)
        jsonDecode(snapshot['tr_history'] as String) as List,
  ];
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'schema': 'typefree.history/1',
        'exportedAt': now,
        'sessions': rows,
        if (recoveryHistories.isNotEmpty)
          'unresolvedHistoryCopies': recoveryHistories,
      }),
    ),
  );
  return (exporter ?? saveArtifact)(
    'TypeFree-history-$now.json',
    bytes,
    'application/json',
  );
}

String progressCopy(String language, String key) {
  const languages = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = {
    'migrationOpen': [
      'Открыть прогресс',
      'View progress',
      'Ver progreso',
      'Fortschritt öffnen',
      'Voir les progrès',
      'Apri progressi',
      'Ver progresso',
    ],
    'migrationPending': [
      'Проверка данных прежней версии не завершена. Если вы обновили приложение, прогресс может быть неполным. Повторим проверку при следующем запуске.',
      'The previous version’s data check is incomplete. If you updated the app, your progress may be incomplete. We will retry on the next launch.',
      'La comprobación de datos anteriores no ha terminado. Si actualizaste la app, tu progreso puede estar incompleto. Se reintentará al iniciarla de nuevo.',
      'Die Prüfung früherer Daten ist nicht abgeschlossen. Nach einem Update kann der Fortschritt unvollständig sein. Beim nächsten Start wird erneut geprüft.',
      'La vérification des données précédentes est incomplète. Après une mise à jour, les progrès peuvent être incomplets. Un nouvel essai aura lieu au prochain lancement.',
      'La verifica dei dati precedenti non è completa. Dopo un aggiornamento i progressi potrebbero essere incompleti. Riproveremo al prossimo avvio.',
      'A verificação dos dados anteriores está incompleta. Se atualizou a aplicação, o progresso pode estar incompleto. Tentaremos novamente no próximo arranque.',
    ],
    'showMore': [
      'Показать ещё',
      'Show more',
      'Mostrar más',
      'Mehr anzeigen',
      'Afficher plus',
      'Mostra altro',
      'Mostrar mais',
    ],
    'recoverySave': [
      'Сохранить копию',
      'Save copy',
      'Guardar copia',
      'Kopie speichern',
      'Enregistrer la copie',
      'Salva copia',
      'Salvar cópia',
    ],
    'recoverySaveHint': [
      'Файл содержит данные этой копии. При восстановлении могут остаться конфликты с текущим прогрессом.',
      'The file contains this copy. Restoring it may conflict with current progress.',
      'El archivo contiene esta copia. Al restaurarla puede haber conflictos con el progreso actual.',
      'Die Datei enthält diese Kopie. Die Wiederherstellung kann mit dem aktuellen Fortschritt in Konflikt stehen.',
      'Le fichier contient cette copie. Sa restauration peut être en conflit avec les progrès actuels.',
      'Il file contiene questa copia. Il ripristino può essere in conflitto con i progressi attuali.',
      'O arquivo contém esta cópia. A restauração pode entrar em conflito com o progresso atual.',
    ],
    'recoveryInvalid': [
      'Некоторые данные прежней версии не удалось прочитать. Они остались в старом хранилище; показанный прогресс может быть неполным.',
      'Some data from the previous version could not be read. It remains in the old storage; the progress shown may be incomplete.',
      'No se pudieron leer algunos datos anteriores. Siguen en el almacenamiento antiguo; el progreso mostrado puede estar incompleto.',
      'Einige Daten der alten Version konnten nicht gelesen werden. Sie bleiben im alten Speicher; der angezeigte Fortschritt kann unvollständig sein.',
      'Certaines données de l’ancienne version sont illisibles. Elles restent dans l’ancien stockage ; les progrès affichés peuvent être incomplets.',
      'Alcuni dati della versione precedente non sono leggibili. Restano nella vecchia memoria; i progressi mostrati potrebbero essere incompleti.',
      'Alguns dados da versão anterior não puderam ser lidos. Eles permanecem no armazenamento antigo; o progresso exibido pode estar incompleto.',
    ],
    'recoveryTitle': [
      'Найдены данные для восстановления',
      'Recovery data found',
      'Datos para recuperar encontrados',
      'Wiederherstellungsdaten gefunden',
      'Données à récupérer trouvées',
      'Dati da recuperare trovati',
      'Dados para recuperação encontrados',
    ],
    'recoveryHint': [
      'Копии показаны отдельно; некоторые записи уже могут учитываться в статистике.',
      'Copies are shown separately; some records may already be included in statistics.',
      'Las copias se muestran aparte; algunos registros ya pueden contar en las estadísticas.',
      'Kopien werden getrennt angezeigt; einige Einträge können bereits in der Statistik enthalten sein.',
      'Les copies sont affichées séparément ; certains résultats peuvent déjà figurer dans les statistiques.',
      'Le copie sono mostrate separatamente; alcuni risultati potrebbero già essere nelle statistiche.',
      'As cópias são mostradas separadamente; alguns registros já podem constar nas estatísticas.',
    ],
    'recoveryCopy': [
      'Копия истории',
      'History copy',
      'Copia del historial',
      'Verlaufskopie',
      'Copie de l’historique',
      'Copia della cronologia',
      'Cópia do histórico',
    ],
    'local': [
      'История на этом устройстве',
      'History on this device',
      'Historial en este dispositivo',
      'Verlauf auf diesem Gerät',
      'Historique sur cet appareil',
      'Cronologia su questo dispositivo',
      'Histórico neste dispositivo',
    ],
    'streak': [
      'Серия дней (UTC)',
      'Day streak (UTC)',
      'Racha (UTC)',
      'Tagesserie (UTC)',
      'Série de jours (UTC)',
      'Serie di giorni (UTC)',
      'Sequência de dias (UTC)',
    ],
    'course': [
      'Звёзды курса',
      'Course stars',
      'Estrellas del curso',
      'Kurssterne',
      'Étoiles du cours',
      'Stelle del corso',
      'Estrelas do curso',
    ],
    'kids': [
      'Звёзды детского курса',
      'Child course stars',
      'Estrellas infantiles',
      'Kinderkurs-Sterne',
      'Étoiles du cours enfant',
      'Stelle corso bambini',
      'Estrelas do curso infantil',
    ],
    'series': [
      'Сопоставимые тренировки',
      'Comparable sessions',
      'Sesiones comparables',
      'Vergleichbare Sitzungen',
      'Séances comparables',
      'Sessioni confrontabili',
      'Sessões comparáveis',
    ],
    'seriesHint': [
      'График и прогноз: один профиль, язык, режим и сложность.',
      'Chart and forecast use one profile, language, mode and difficulty.',
      'Gráfico y previsión: mismo perfil, idioma, modo y dificultad.',
      'Diagramm und Prognose: gleiches Profil, Sprache, Modus und Schwierigkeit.',
      'Graphique et prévision : mêmes profil, langue, mode et difficulté.',
      'Grafico e previsione: stesso profilo, lingua, modalità e difficoltà.',
      'Gráfico e previsão: mesmo perfil, idioma, modo e dificuldade.',
    ],
    'yours': [
      'Ваш прогресс',
      'Your progress',
      'Tu progreso',
      'Dein Fortschritt',
      'Vos progrès',
      'I tuoi progressi',
      'O seu progresso',
    ],
    'speed': [
      'Скорость (WPM)',
      'Speed (WPM)',
      'Velocidad (WPM)',
      'Tempo (WPM)',
      'Vitesse (WPM)',
      'Velocità (WPM)',
      'Velocidade (WPM)',
    ],
    'acc': [
      'Точность (%)',
      'Accuracy (%)',
      'Precisión (%)',
      'Genauigkeit (%)',
      'Précision (%)',
      'Precisione (%)',
      'Precisão (%)',
    ],
    'best': [
      'лучшая скорость, WPM',
      'best speed, WPM',
      'mejor velocidad, WPM',
      'Bestwert, WPM',
      'meilleure vitesse, WPM',
      'velocità migliore, WPM',
      'melhor velocidade, WPM',
    ],
    'noSessions': [
      'Тренировок пока нет — они появятся здесь.',
      'No sessions yet — they will appear here.',
      'Aún no hay sesiones; aparecerán aquí.',
      'Noch keine Sitzungen – sie erscheinen hier.',
      'Pas encore de séance — elles apparaîtront ici.',
      'Nessuna sessione ancora: appariranno qui.',
      'Ainda sem sessões — vão aparecer aqui.',
    ],
    'days7': [
      '7 дней',
      '7 days',
      '7 días',
      '7 Tage',
      '7 jours',
      '7 giorni',
      '7 dias',
    ],
    'days30': [
      '30 дней',
      '30 days',
      '30 días',
      '30 Tage',
      '30 jours',
      '30 giorni',
      '30 dias',
    ],
    'allTime': [
      'Всё время',
      'All time',
      'Todo',
      'Gesamt',
      'Tout',
      'Sempre',
      'Sempre',
    ],
    'recent': [
      'Последние тренировки',
      'Recent sessions',
      'Sesiones recientes',
      'Letzte Sitzungen',
      'Séances récentes',
      'Sessioni recenti',
      'Sessões recentes',
    ],
    'saveTarget': [
      'Сохранить цель',
      'Save target',
      'Guardar meta',
      'Ziel speichern',
      'Enregistrer l’objectif',
      'Salva obiettivo',
      'Salvar meta',
    ],
    'noForecast': [
      'Для этой серии прогноз пока не сформирован.',
      'No forecast is available for this series yet.',
      'Aún no hay datos estables para prever.',
      'Noch kein ausreichend stabiler Trend für eine Prognose.',
      'Pas encore assez de données stables pour une prévision.',
      'Dati stabili insufficienti per una previsione.',
      'Ainda faltam dados estáveis para uma previsão.',
    ],
    'globalBadges': [
      'Общие достижения устройства, включая прежние.',
      'Device-wide achievements, including previous ones.',
      'Logros del dispositivo, incluidos los anteriores.',
      'Geräteweite Erfolge einschließlich früherer.',
      'Succès de l’appareil, y compris les anciens.',
      'Traguardi del dispositivo, inclusi quelli precedenti.',
      'Conquistas do dispositivo, incluindo anteriores.',
    ],
    'earned': [
      'Получено',
      'Earned',
      'Obtenido',
      'Erreicht',
      'Obtenu',
      'Ottenuto',
      'Obtido',
    ],
    'locked': [
      'Пока закрыто',
      'Locked',
      'Bloqueado',
      'Gesperrt',
      'Verrouillé',
      'Bloccato',
      'Bloqueado',
    ],
    'archivedBadges': [
      'Другие сохранённые достижения',
      'Other preserved achievements',
      'Otros logros guardados',
      'Andere erhaltene Erfolge',
      'Autres succès conservés',
      'Altri traguardi conservati',
      'Outras conquistas preservadas',
    ],
    'export': [
      'Экспорт всей истории (JSON)',
      'Export all history (JSON)',
      'Exportar todo el historial (JSON)',
      'Gesamten Verlauf exportieren (JSON)',
      'Exporter tout l’historique (JSON)',
      'Esporta tutta la cronologia (JSON)',
      'Exportar todo o histórico (JSON)',
    ],
    'saved': [
      'Сохранено',
      'Saved',
      'Guardado',
      'Gespeichert',
      'Enregistré',
      'Salvato',
      'Salvo',
    ],
    'requested': [
      'Файл передан для сохранения',
      'File handed off for saving',
      'Archivo enviado para guardar',
      'Datei zum Speichern übergeben',
      'Fichier transmis pour enregistrement',
      'File inviato per il salvataggio',
      'Arquivo enviado para salvar',
    ],
    'cancelled': [
      'Сохранение отменено',
      'Save cancelled',
      'Guardado cancelado',
      'Speichern abgebrochen',
      'Enregistrement annulé',
      'Salvataggio annullato',
      'Salvamento cancelado',
    ],
    'failed': [
      'Не удалось сохранить. Можно повторить.',
      'Could not save. You can retry.',
      'No se pudo guardar. Reintenta.',
      'Speichern fehlgeschlagen. Erneut versuchen.',
      'Échec de l’enregistrement. Réessayez.',
      'Salvataggio fallito. Riprova.',
      'Não foi possível salvar. Tente novamente.',
    ],
    'invalid': [
      'Введите целую положительную скорость WPM.',
      'Enter a positive whole-number WPM target.',
      'Introduce un objetivo WPM entero positivo.',
      'Positives ganzzahliges WPM-Ziel eingeben.',
      'Saisissez un objectif WPM entier positif.',
      'Inserisci un obiettivo WPM intero positivo.',
      'Insira uma meta WPM inteira positiva.',
    ],
    'unknown': [
      'В старых записях неизвестны профиль, язык и упражнение. Они сохранены отдельно от сопоставимых серий.',
      'Old records lack profile, language and exercise metadata. They stay outside comparable series.',
      'Los registros antiguos no indican perfil, idioma ni ejercicio; quedan fuera de series comparables.',
      'Alte Einträge ohne Profil, Sprache und Übung gehören nicht zu vergleichbaren Serien.',
      'Les anciens résultats sans profil, langue ni exercice restent hors des séries comparables.',
      'I vecchi risultati senza profilo, lingua o esercizio restano fuori dalle serie confrontabili.',
      'Registros antigos sem perfil, idioma ou exercício ficam fora das séries comparáveis.',
    ],
    'oldSession': [
      'Тренировка из прежней версии',
      'Session from the previous version',
      'Sesión de la versión anterior',
      'Sitzung aus der vorherigen Version',
      'Séance de l’ancienne version',
      'Sessione della versione precedente',
      'Sessão da versão anterior',
    ],
    'banks': [
      'Прогресс по наборам',
      'Progress by collection',
      'Progreso por conjunto',
      'Fortschritt nach Sammlung',
      'Progrès par collection',
      'Progressi per raccolta',
      'Progresso por coleção',
    ],
    'completed': [
      'Пройдено',
      'Completed',
      'Completado',
      'Abgeschlossen',
      'Terminé',
      'Completato',
      'Concluído',
    ],
  };
  final index = languages.indexOf(language);
  return words[key]?[index < 0 ? 1 : index] ?? key;
}

/// Unknown future modes remain visible rather than being mislabeled.
String progressModeLabel(String language, String mode) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const labels = <String, List<String>>{
    'practice': [
      'Тренировка',
      'Practice',
      'Práctica',
      'Training',
      'Entraînement',
      'Pratica',
      'Prática',
    ],
    'weak': [
      'Слабые клавиши',
      'Weak keys',
      'Teclas débiles',
      'Schwache Tasten',
      'Touches difficiles',
      'Tasti deboli',
      'Teclas difíceis',
    ],
    'course': [
      'Курс печати',
      'Typing course',
      'Curso de mecanografía',
      'Schreibkurs',
      'Cours de frappe',
      'Corso di dattilografia',
      'Curso de digitação',
    ],
    'learn': [
      'AI-обучение',
      'AI learning',
      'Aprendizaje con IA',
      'KI-Lernen',
      'Apprentissage IA',
      'Apprendimento IA',
      'Aprendizagem com IA',
    ],
    'compete': [
      'Соревнование',
      'Competition',
      'Competición',
      'Wettbewerb',
      'Compétition',
      'Competizione',
      'Competição',
    ],
    'memorize': [
      'Наизусть',
      'Memorization',
      'Memorización',
      'Auswendiglernen',
      'Mémorisation',
      'Memorizzazione',
      'Memorização',
    ],
    'recall': [
      'Память',
      'Memory',
      'Memoria',
      'Gedächtnis',
      'Mémoire',
      'Memoria',
      'Memória',
    ],
    'exam': [
      'Тест печати',
      'Typing test',
      'Prueba de mecanografía',
      'Tipptest',
      'Test de frappe',
      'Test di digitazione',
      'Teste de digitação',
    ],
  };
  final i = langs.indexOf(language);
  return labels[mode]?[i < 0 ? 1 : i] ?? mode;
}
