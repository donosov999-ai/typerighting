import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/domain/typing.dart';

/// A blocked wrong key leaves marks as «correct» once fixed; missedAt keeps
/// the fact that the position had a mistake.
void main() {
  test('blocked mistake is remembered in missedAt, marks stay correct', () {
    final s = TypingSession(['кот'], clock: () => 0);
    s.press('x', blockOnError: true);
    s.press('к', blockOnError: true);
    s.press('о', blockOnError: true);
    s.press('т', blockOnError: true);
    expect(s.marks.toList(), [1, 1, 1]);
    expect(s.missedAt, {0});
    expect(s.errors, 1);
  });
}
