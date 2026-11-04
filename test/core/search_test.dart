import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/search.dart';

void main() {
  test('searchWords splits on whitespace and lower-cases', () {
    expect(searchWords('  Chick   BREAST '), ['chick', 'breast']);
    expect(searchWords('   '), isEmpty);
  });

  test('matchesSearch needs every word, in any order, in any field', () {
    expect(matchesSearch('chick breast', ['Chicken breast, grilled']), isTrue);
    expect(matchesSearch('breast chick', ['Chicken breast']), isTrue);
    expect(matchesSearch('chick thigh', ['Chicken breast']), isFalse);
    expect(matchesSearch('acme oats', ['Rolled oats', 'Acme']), isTrue);
    expect(matchesSearch('acme', ['Rolled oats', null]), isFalse);
    expect(matchesSearch('', ['Anything']), isTrue);
  });
}
