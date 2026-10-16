import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_seisei_ai_passport/unofficial_notice.dart';

void main() {
  test('非公式表示の文言は提携・許諾を主張しない', () {
    expect(kUnofficialNotice, contains('非公式'));
    expect(kUnofficialNotice, contains('関係のない'));
    expect(kTrademarkNotice, contains('商標'));
    expect('$kUnofficialNotice$kTrademarkNotice', isNot(contains('公認')));
    expect('$kUnofficialNotice$kTrademarkNotice', isNot(contains('許諾を得')));
  });
}
