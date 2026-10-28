import 'package:flutter_test/flutter_test.dart';
import 'package:typefree_flutter_foundation/features/recall_page.dart';

/// Russian word counts take the right form (the source always said «слов»).
void main() {
  test('Russian plural for word counts', () {
    String tr(String k) => k == 'span.words' ? 'words' : k;
    expect(spanWords(1, 'ru', tr), '1 слово');
    expect(spanWords(3, 'ru', tr), '3 слова');
    expect(spanWords(5, 'ru', tr), '5 слов');
    expect(spanWords(11, 'ru', tr), '11 слов');
    expect(spanWords(21, 'ru', tr), '21 слово');
    expect(spanWords(22, 'ru', tr), '22 слова');
    expect(spanWords(1, 'en', tr), '1 word');
    expect(spanWords(4, 'en', tr), '4 words');
  });
}
