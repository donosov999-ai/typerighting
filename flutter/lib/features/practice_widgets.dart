import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/typing.dart';
import '../design_system/templates.dart';

class PatternView extends StatefulWidget {
  const PatternView({
    super.key,
    required this.session,
    this.displayPattern,
    this.fontSize = 28,
  });
  final TypingSession session;
  final String? displayPattern;

  /// 28 by default; larger for the child profile (D3).
  final double fontSize;
  @override
  State<PatternView> createState() => _PatternViewState();
}

class _PatternViewState extends State<PatternView> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final displayed = widget.displayPattern ?? session.pattern;
    assert(displayed.length == session.pattern.length);
    final t = Theme.of(context).extension<TypeFreeTokens>()!;
    final span = TextSpan(
      style: TextStyle(
        fontSize: widget.fontSize,
        height: 1.6,
        fontFamily: 'monospace',
        color: t['text'],
      ),
      children: List.generate(
        session.pattern.length,
        (i) => TextSpan(
          text: displayed[i],
          style: TextStyle(
            color: i == session.pos
                ? t['onExpectedKey']
                : session.marks[i] == 1
                ? t['success']
                : session.marks[i] == 2
                ? t['danger']
                : t['text'],
            backgroundColor: i == session.pos ? t['expectedKey'] : null,
          ),
        ),
      ),
    );
    return SizedBox(
      // One line and a bit: 62 at the default 28.
      height: widget.fontSize * 62 / 28,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final painter = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: bounds.maxWidth);
          final y = painter
              .getOffsetForCaret(
                TextPosition(
                  offset: session.pos.clamp(0, session.pattern.length),
                ),
                Rect.zero,
              )
              .dy;
          final lineHeight = painter.preferredLineHeight;
          painter.dispose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !scroll.hasClients) return;
            final current = scroll.offset;
            final bottom = y + lineHeight;
            final target = y < current
                ? y
                : bottom > current + 62
                ? bottom - 62
                : current;
            final clamped = target.clamp(0.0, scroll.position.maxScrollExtent);
            if ((current - clamped).abs() > .5) scroll.jumpTo(clamped);
          });
          return SingleChildScrollView(
            controller: scroll,
            child: Text.rich(span),
          );
        },
      ),
    );
  }
}

class PracticeCommitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    if (next.composing.isValid && !next.composing.isCollapsed) return next;
    if (old.composing.isValid && !old.composing.isCollapsed) return next;
    return next.text.length - old.text.length > 1 ? old : next;
  }
}
