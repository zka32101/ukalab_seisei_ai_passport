import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_seisei_ai_passport/data/revenuecat_key.dart';

void main() {
  String? key({bool web = false, bool android = false, bool ios = false, String g = '', String a = ''}) =>
      revenueCatKeyFor(isWeb: web, isAndroid: android, isIOS: ios, googleKey: g, appleKey: a);

  test('キー未指定ならどのプラットフォームでも null（従来どおり Fake）', () {
    expect(key(android: true), isNull);
    expect(key(ios: true), isNull);
    expect(key(), isNull);
  });

  test('Android は RC_GOOGLE_KEY、iOS は RC_APPLE_KEY を使う', () {
    expect(key(android: true, g: 'goog_x', a: 'appl_y'), 'goog_x');
    expect(key(ios: true, g: 'goog_x', a: 'appl_y'), 'appl_y');
  });

  test('該当プラットフォームのキーだけが空なら null', () {
    expect(key(ios: true, g: 'goog_x'), isNull);
    expect(key(android: true, a: 'appl_y'), isNull);
  });

  test('Web・その他では常に null', () {
    expect(key(web: true, android: true, g: 'goog_x', a: 'appl_y'), isNull);
    expect(key(g: 'goog_x', a: 'appl_y'), isNull);
  });

  test('既定値（dart-define なし）は空', () {
    expect(rcGoogleKey, isEmpty);
    expect(rcAppleKey, isEmpty);
  });
}
