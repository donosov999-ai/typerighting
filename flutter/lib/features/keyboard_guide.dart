import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/templates.dart';

class KeyboardModel {
  KeyboardModel(this.snapshot);
  final Map<String, dynamic> snapshot;
  Map<String, dynamic>? hit(String ch, {required bool ru}) {
    Object? value;
    if (RegExp('[а-яё]', caseSensitive: false).hasMatch(ch)) {
      value = (snapshot['ru'] as Map)[ch];
    } else {
      if (snapshot['layoutName'] != 'qwerty') {
        value = (snapshot['layout'] as Map)[ch];
      }
      if (value == null && RegExp('[a-z]', caseSensitive: false).hasMatch(ch)) {
        value = (snapshot['en'] as Map)[ch];
      }
      value ??=
          (ru ? snapshot['ru'] as Map : snapshot['en'] as Map)[ch] ??
          (ru ? snapshot['en'] as Map : snapshot['ru'] as Map)[ch];
    }
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String bridge(String input, String expected) {
    if (input.length != 1 || expected.length != 1) return input;
    final lower = input.toLowerCase();
    final reverse = RegExp('[а-яё]', caseSensitive: false).hasMatch(input);
    for (final g in snapshot['keys'] as List) {
      // Raw QWERTY base is exported separately for the legacy physical bridge.
      final en = g['baseEn'], ru = g['ru'];
      if (en is! String || ru is! String) continue;
      if (reverse &&
          RegExp('[a-z]', caseSensitive: false).hasMatch(expected) &&
          ru.toLowerCase() == lower) {
        return input == lower ? en.toLowerCase() : en.toUpperCase();
      }
      if (!reverse &&
          RegExp('[а-яё]', caseSensitive: false).hasMatch(expected) &&
          en.toLowerCase() == lower) {
        return input == lower ? ru.toLowerCase() : ru.toUpperCase();
      }
    }
    return input;
  }
}

/// Five-row guide at its real proportions (DESIGN_TEMPLATE_REF §6): narrower
/// than 740 it scrolls sideways with an explicit hint and keeps the expected
/// key in view, instead of shrinking legends.
class KeyboardGuide extends StatefulWidget {
  const KeyboardGuide({
    super.key,
    required this.model,
    required this.expected,
    required this.ru,
    this.heat = const {},
    this.language = 'ru',
  });
  final KeyboardModel model;
  final String? expected;
  final bool ru;
  final Map<String, double> heat;
  final String language;
  @override
  State<KeyboardGuide> createState() => _KeyboardGuideState();
}

String keyboardScrollHint(String language) {
  const langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  const words = [
    'Клавиатура листается вбок и сама показывает нужную клавишу. Целиком — в горизонтальном положении.',
    'The keyboard scrolls sideways and follows the next key. Turn the device to see all of it.',
    'El teclado se desplaza y sigue la siguiente tecla. Gira el dispositivo para verlo entero.',
    'Die Tastatur scrollt seitlich und folgt der nächsten Taste. Quer gedreht ist sie ganz sichtbar.',
    'Le clavier défile et suit la touche suivante. Tournez l’appareil pour le voir en entier.',
    'La tastiera scorre e segue il tasto successivo. Ruota il dispositivo per vederla tutta.',
    'O teclado desliza e acompanha a próxima tecla. Rode o dispositivo para o ver inteiro.',
  ];
  final i = langs.indexOf(language);
  return words[i < 0 ? 1 : i];
}

class _KeyboardGuideState extends State<KeyboardGuide> {
  final scroll = ScrollController();
  double width = 740, viewport = 740;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  /// Centre the expected key (and its Shift partner stays reachable by swipe).
  void follow() {
    if (!scroll.hasClients || width <= viewport) return;
    final hit = widget.expected == null
        ? null
        : widget.model.hit(widget.expected!, ru: widget.ru);
    if (hit == null) return;
    for (final raw in widget.model.snapshot['keys'] as List) {
      final g = raw as Map;
      if (g['id'] != hit['id']) continue;
      final centre =
          ((g['x'] as num) + (g['w'] as num) / 2).toDouble() * width / 920;
      final target = (centre - viewport / 2).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      );
      if ((scroll.offset - target).abs() > viewport / 4) scroll.jumpTo(target);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TypeFreeTokens>()!;
    return LayoutBuilder(
      builder: (context, c) {
        // B1/B2: the model's full 920 on tall screens; on 720-high laptops
        // 820 keeps the guide above the fold.
        final cap = MediaQuery.sizeOf(context).height >= 860 ? 920.0 : 820.0;
        width = math.max(740.0, math.min(cap, c.maxWidth));
        viewport = c.maxWidth;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) follow();
        });
        final guide = Semantics(
          label: widget.expected == null
              ? 'Клавиатура'
              : 'Следующий символ: ${widget.expected}',
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: width * 380 / 920,
              child: CustomPaint(
                painter: _GuidePainter(
                  widget.model,
                  widget.expected,
                  widget.ru,
                  tokens,
                  widget.heat,
                ),
              ),
            ),
          ),
        );
        if (width <= c.maxWidth) return guide;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      keyboardScrollHint(widget.language),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            guide,
          ],
        );
      },
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.model, this.expected, this.ru, this.tokens, this.heat);
  final KeyboardModel model;
  final String? expected;
  final bool ru;
  final TypeFreeTokens tokens;
  final Map<String, double> heat;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 920, size.height / 380);
    final hit = expected == null ? null : model.hit(expected!, ru: ru);
    final id = hit?['id'],
        left = (model.snapshot['leftHand'] as List).contains(id);
    final shift = hit?['shift'] == true ? (left ? 'rshift' : 'lshift') : null;
    final keys = model.snapshot['keys'] as List;
    for (final raw in keys) {
      final g = raw as Map;
      final rect = Rect.fromLTWH(
        (g['x'] as num).toDouble(),
        (g['y'] as num).toDouble(),
        (g['w'] as num).toDouble(),
        (g['h'] as num).toDouble(),
      );
      final active = g['id'] == id, shifting = g['id'] == shift;
      final rate = heat[g['id']];
      final face = rate == null
          ? tokens['keyboardFace']
          : Color.lerp(
              tokens['success'],
              tokens['danger'],
              (rate * 3).clamp(0, 1),
            )!.withValues(alpha: .45);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = active
              ? tokens['expectedKey']
              : shifting
              ? tokens['shiftKey']
              : face,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = tokens['keyboardBase']
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final main = (g['label'] ?? g['en'] ?? '').toString();
      final first = g['id'] == 'space'
          ? 'Space'
          : g['id'] == 'backspace'
          ? 'Back'
          : main;
      final color = active
          ? tokens['onExpectedKey']
          : shifting
          ? tokens['onShiftKey']
          : tokens['keyboardLegend'];
      void text(String s, Offset at, double fs, Color col) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
              color: col,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width - 8);
        tp.paint(canvas, at);
      }

      text(
        first,
        Offset(rect.left + 7, rect.top + (g['label'] != null ? 20 : 22)),
        main.length > 3 ? 15 : 22,
        color,
      );
      if (ru && g['ru'] != null) {
        text(
          g['ru'] as String,
          Offset(rect.right - 23, rect.bottom - 24),
          16,
          active ? tokens['onExpectedKey'] : tokens['keyboardSecondaryLegend'],
        );
      }
      if (g['en2'] != null) {
        text(
          g['en2'] as String,
          Offset(rect.left + 8, rect.top + 3),
          12,
          color,
        );
      }
    }
    final homeId = (model.snapshot['homeOf'] as Map)[id];
    final homes = keys.where((g) => g['id'] == homeId).toList(),
        targets = keys.where((g) => g['id'] == id).toList();
    if (homes.isNotEmpty && targets.isNotEmpty && homeId != id) {
      Offset center(Map g) => Offset(
        (g['x'] as num).toDouble() + (g['w'] as num) / 2,
        (g['y'] as num).toDouble() + (g['h'] as num) / 2,
      );
      final a = center(homes.first as Map), b = center(targets.first as Map);
      final bend = math.max(28.0, (b - a).distance * .55);
      final c = (a + b) / 2 + Offset(left ? -bend : bend, -22);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = tokens['focusRing']
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
      final angle = math.atan2(b.dy - c.dy, b.dx - c.dx);
      canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(
            b.dx - 13 * math.cos(angle - .4),
            b.dy - 13 * math.sin(angle - .4),
          )
          ..lineTo(
            b.dx - 13 * math.cos(angle + .4),
            b.dy - 13 * math.sin(angle + .4),
          )
          ..close(),
        Paint()..color = tokens['focusRing'],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => true;
}

/// «Which finger» for the next key, derived from the source keyboard data:
/// homeOf maps a key to its finger's home key; home keys map to themselves.
/// D3 shows it to children. Null when the key has no finger (e.g. Enter).
String? fingerHint(
  KeyboardModel model,
  String? expected,
  bool ru,
  String language,
) {
  if (expected == null) return null;
  final hit = model.hit(expected, ru: ru);
  final id = hit?['id'] as String?;
  if (id == null) return null;
  const homes = {'a', 's', 'd', 'f', 'j', 'k', 'l', 'semi'};
  final langs = ['ru', 'en', 'es', 'de', 'fr', 'it', 'pt'];
  final i = langs.indexOf(language) < 0 ? 1 : langs.indexOf(language);
  if (id == 'space') {
    return const [
      'Большой палец',
      'Thumb',
      'Pulgar',
      'Daumen',
      'Pouce',
      'Pollice',
      'Polegar',
    ][i];
  }
  final home =
      (model.snapshot['homeOf'] as Map)[id] as String? ??
      (homes.contains(id) ? id : null);
  if (home == null) return null;
  const fingers = {
    'f': [
      'указательный',
      'index',
      'índice',
      'Zeigefinger',
      'index',
      'indice',
      'indicador',
    ],
    'j': [
      'указательный',
      'index',
      'índice',
      'Zeigefinger',
      'index',
      'indice',
      'indicador',
    ],
    'd': [
      'средний',
      'middle',
      'corazón',
      'Mittelfinger',
      'majeur',
      'medio',
      'médio',
    ],
    'k': [
      'средний',
      'middle',
      'corazón',
      'Mittelfinger',
      'majeur',
      'medio',
      'médio',
    ],
    's': [
      'безымянный',
      'ring',
      'anular',
      'Ringfinger',
      'annulaire',
      'anulare',
      'anelar',
    ],
    'l': [
      'безымянный',
      'ring',
      'anular',
      'Ringfinger',
      'annulaire',
      'anulare',
      'anelar',
    ],
    'a': [
      'мизинец',
      'little',
      'meñique',
      'kleiner Finger',
      'auriculaire',
      'mignolo',
      'mínimo',
    ],
    'semi': [
      'мизинец',
      'little',
      'meñique',
      'kleiner Finger',
      'auriculaire',
      'mignolo',
      'mínimo',
    ],
  };
  final left = const {'a', 's', 'd', 'f'}.contains(home);
  final hand = left
      ? const [
          'левой руки',
          'left hand',
          'mano izquierda',
          'linke Hand',
          'main gauche',
          'mano sinistra',
          'mão esquerda',
        ][i]
      : const [
          'правой руки',
          'right hand',
          'mano derecha',
          'rechte Hand',
          'main droite',
          'mano destra',
          'mão direita',
        ][i];
  final finger = fingers[home]![i];
  return language == 'ru'
      ? 'Жми: $finger палец $hand'
      : language == 'en'
      ? 'Use your ${left ? 'left' : 'right'} $finger finger'
      : '$finger · $hand';
}
