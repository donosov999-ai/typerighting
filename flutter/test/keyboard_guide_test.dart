import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/design_system/templates.dart';
import 'package:typefree_flutter_foundation/features/keyboard_guide.dart';
import 'package:typefree_flutter_foundation/main.dart';

/// DESIGN_TEMPLATE_REF §6: under 740 px the five-row guide keeps its size,
/// scrolls sideways with an explicit hint and keeps the next key in view.
void main() {
  testWidgets('D3 finger hint comes from homeOf, both hands, RU and EN', (
    tester,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final model = KeyboardModel(
      Map<String, dynamic>.from(
        (resources.keyboards['windows'] as Map)['qwerty'] as Map,
      ),
    );
    expect(
      fingerHint(model, 'ц', true, 'ru'),
      'Жми: безымянный палец левой руки',
      reason: 'ц = W → home S',
    );
    expect(fingerHint(model, 'f', false, 'en'), 'Use your left index finger');
    expect(
      fingerHint(model, 'o', false, 'en'),
      'Use your right ring finger',
      reason: 'O → home L',
    );
    expect(fingerHint(model, ' ', false, 'ru'), 'Большой палец');
    expect(fingerHint(model, null, false, 'ru'), isNull);
    for (final language in ['es', 'de', 'fr', 'it', 'pt']) {
      expect(fingerHint(model, 'k', false, language), isNotEmpty);
    }
  });

  testWidgets('narrow guide: hint, real size, follows the expected key', (
    tester,
  ) async {
    final resources = (await tester.runAsync(Resources.load))!;
    final model = KeyboardModel(
      Map<String, dynamic>.from(
        (resources.keyboards['windows'] as Map)['qwerty'] as Map,
      ),
    );
    final theme = AppearanceController(
      resources.registry,
      _Memory(),
      existingInstall: true,
    ).theme(Brightness.dark);
    Future<ScrollPosition> show(String? expected, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: KeyboardGuide(
                  model: model,
                  expected: expected,
                  ru: false,
                  language: 'en',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<ScrollableState>(find.byType(Scrollable)).position;
    }

    var pos = await show('p', 390);
    expect(find.text(keyboardScrollHint('en')), findsOneWidget);
    expect(
      tester.getSize(find.byType(CustomPaint).last).width,
      740,
      reason: 'no shrinking',
    );
    expect(
      pos.pixels,
      greaterThan(0),
      reason: '«p» is on the right: scrolled to it',
    );
    pos = await show('q', 390);
    expect(pos.pixels, 0, reason: '«q» is on the left');
    pos = await show(null, 390);
    expect(pos.pixels, 0);

    await show('p', 900);
    expect(
      find.text(keyboardScrollHint('en')),
      findsNothing,
      reason: 'wide: no hint',
    );
    expect(tester.takeException(), isNull);
  });
}

class _Memory implements AppearanceStore {
  @override
  Future<void> save(Map<String, Object> value) async {}
}
