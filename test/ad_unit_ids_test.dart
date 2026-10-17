import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_seisei_ai_passport/data/ad_unit_ids.dart';

void main() {
  List<String> ids({
    bool web = false,
    bool android = true,
    bool release = true,
    String b = '',
    String i = '',
    String r = '',
  }) {
    final u = adUnitIdsFor(
      isWeb: web,
      isAndroid: android,
      isRelease: release,
      banner: b,
      interstitial: i,
      rewarded: r,
    );
    return [u.banner, u.interstitial, u.rewarded];
  }

  test('Web・iOS は空のID（広告なし）', () {
    expect(ids(web: true), ['', '', '']);
    expect(ids(android: false), ['', '', '']);
  });

  test('Android のデバッグ・profile はテスト広告（本番IDを渡しても使わない）', () {
    expect(ids(release: false).first, startsWith('ca-app-pub-3940256099942544/'));
    expect(ids(release: false, b: 'ca-app-pub-9/1').first, startsWith('ca-app-pub-3940256099942544/'));
  });

  test('Android のリリースは渡された本番ID', () {
    expect(ids(b: 'ca-app-pub-9/1', i: 'ca-app-pub-9/2', r: 'ca-app-pub-9/3'),
        ['ca-app-pub-9/1', 'ca-app-pub-9/2', 'ca-app-pub-9/3']);
  });

  test('Android のリリースで未指定なら空のID（テストIDを残さない）', () {
    expect(ids(), ['', '', '']);
  });
}
