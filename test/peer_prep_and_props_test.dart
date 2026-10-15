import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart' show PeerStatsCard;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/oshi_recap.dart';
import 'package:ukalab_seisei_ai_passport/data/peer_stats_prep.dart';
import 'package:ukalab_seisei_ai_passport/widgets/cert_prop_badge.dart';
import 'package:ukalab_seisei_ai_passport/widgets/peer_stats_settings_tile.dart';

ProgressRecord _r(String qid, int day) =>
    ProgressRecord(qid: qid, subjectId: 's', correct: true, at: DateTime(2026, 10, day, 9));

class _MemSettings implements PeerStatsSettings {
  bool v = false;
  @override
  Future<bool> isSharingEnabled() async => v;
  @override
  Future<void> setSharingEnabled(bool e) async => v = e;
}

void main() {
  group('PeerStatsSettings', () {
    test('既定OFF・保存・復元', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SharedPrefsPeerStatsSettings().isSharingEnabled(), isFalse);
      await SharedPrefsPeerStatsSettings().setSharingEnabled(true);
      expect(await SharedPrefsPeerStatsSettings().isSharingEnabled(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ukalab_seisei_ai_passport_peer_stats_sharing_v1'), isTrue);
      await SharedPrefsPeerStatsSettings().setSharingEnabled(false);
      expect(await SharedPrefsPeerStatsSettings().isSharingEnabled(), isFalse);
    });
  });

  test('ローカル値の取り出しが既存値と一致する', () {
    final records = [_r('a', 14), _r('a', 15), _r('b', 15)];
    final now = DateTime(2026, 10, 15, 12);
    final v = peerLocalValuesFrom(
        records: records, now: now, examDate: DateTime(2026, 12, 1));
    expect(v.streakDays, currentStreakDays(records, now));
    expect(v.streakDays, 2);
    expect(v.totalAnswers, 3);
    expect(v.totalAnswers, oshiGrowthProgressFor(records).totalAnswered);
    expect(v.distinctQuestions, 2);
    expect(v.examDate, DateTime(2026, 12, 1));
    expect(peerLocalValuesFrom(records: const [], now: now).examDate, isNull);
    expect(peerLocalValuesFrom(records: const [], now: now).streakDays, 0);
  });

  test('設定スイッチの表示フラグは本番で false', () {
    expect(kPeerStatsSettingsVisible, isFalse);
  });

  testWidgets('設定スイッチ（ウィジェット単体）: 説明文・既定OFF・切り替えで保存', (tester) async {
    final s = _MemSettings();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PeerStatsSettingsTile(settings: s))));
    await tester.pumpAndSettle();
    expect(find.text('匿名の集計に参加する'), findsOneWidget);
    expect(find.textContaining('連続学習日数・累計の問題数・試験日'), findsOneWidget);
    expect(find.textContaining('オフのままでも'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(s.v, isTrue);
  });

  testWidgets('PeerStatsCard はモックのスナップショットで表示できる（ホームには置かない）', (tester) async {
    const snap = PeerStatsSnapshot(
        asOf: '2026-10-15',
        activeToday: 1234,
        participants: 5000,
        totalQuestions: 900000,
        medianQuestions: 120);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PeerStatsCard(snapshot: snap, streakDays: 3))));
    expect(find.byType(Card), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PeerStatsCard(snapshot: null))));
    expect(find.byType(Card), findsNothing);
  });

  group('CertPropBadge', () {
    testWidgets('小さい幅でもオーバーフローせず、画像を出す', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Row(children: [
            Expanded(child: Text('うかラボ 生成AIパスポート 生成AIパスポート試験対策')),
            SizedBox(width: 8),
            CertPropBadge(),
          ]),
        ),
      ));
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('画像読込失敗時は非表示にフォールバック（例外なし）', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CertPropBadge())));
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      final fallback = image.errorBuilder!(tester.element(find.byType(Image)), 'x', null);
      expect(fallback, isA<SizedBox>());
      expect(find.byType(IgnorePointer), findsWidgets);
    });
  });
}
