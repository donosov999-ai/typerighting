import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/memorize.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/memorize.json').readAsStringSync()) as Map;
  final catalog =
      jsonDecode(
            File('assets/baseline/catalog.json').readAsStringSync(),
          )['catalog']
          as Map;
  final library = MemorizeLibrary(Map<String, dynamic>.from(catalog));
  test('112 source scenarios: both literary sources, 7 languages, 4 lengths and 560 masked passes', () {
    for (final item in fixture['cases'] as List) {
      var at = 100000, recorded = 0;
      final engine = MemorizeSession(
        library: library,
        source: item['source'],
        language: item['language'],
        lengthIndex: item['length'],
        clock: () => at,
        record: (_, _, _) => recorded++,
      );
      expect(
        library.pieces(item['source'], item['language'], item['length']),
        item['pieces'],
      );
      for (var pass = 0; pass < 5; pass++) {
        final oracle = item['passes'][pass], before = oracle['before'];
        expect(engine.typing.pattern, before['pattern']);
        expect(engine.wordOf, before['wordOf']);
        expect(engine.firstLetter, before['firstLetter']);
        expect(engine.isAlpha, before['isAlpha']);
        expect(engine.displayPattern, before['display']);
        final pattern = engine.text;
        for (var i = 0; i < pattern.length; i++) {
          final pos = engine.typing.pos;
          engine.press('Backspace');
          expect(engine.typing.pos, pos);
          if (item['errors'] == true && i % 2 == 0) {
            at += 90;
            engine.press('§');
          }
          at += 150;
          engine.press(pattern[i]);
          if (i == pattern.length ~/ 2) {
            expect(engine.displayPattern, oracle['mid'][0]['display']);
          }
        }
        final after = oracle['after'];
        expect(engine.lengthIndex, after['lenIdx']);
        expect(engine.level, after['level']);
        expect(engine.typing.errors, after['errors']);
        expect(engine.passResults.map((r) => r.wpm).toList(), after['passWpm']);
        expect(engine.result!.accuracy, after['recall']);
        expect(engine.lengthIncreased, after['lenUp']);
        final evidence = recorded;
        engine.press('x');
        expect(recorded, evidence);
        if (pass < 4) engine.nextPass();
      }
      expect(engine.finished, true);
      final index = engine.pieceIndex, length = engine.lengthIndex;
      engine.nextPiece();
      expect(
        engine.pieceIndex,
        (index + 1) %
            library.pieces(item['source'], item['language'], length).length,
      );
    }
  });
  test('cleaning splits dash variants, removes punctuation, keeps Unicode letters and digits', () {
    expect(memorizeCleanWords(['Привет—мир! café-42 – да, ёж.']), [
      'Привет',
      'мир',
      'café',
      '42',
      'да',
      'ёж',
    ]);
    expect(
      () => MemorizeSession(
        library: library,
        source: 'classic',
        language: 'en',
        lengthIndex: 4,
        clock: () => 0,
      ),
      throwsArgumentError,
    );
  });
}
