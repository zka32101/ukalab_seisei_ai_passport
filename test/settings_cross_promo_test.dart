import 'package:app_common_kit/app_common_kit.dart'
    show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromoSection;
import 'package:ukalab_core/src/cross_promo_test_support.dart' show ukalabCrossPromoSectionForTest;
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const appId = 'com.yourwish.ukalab.seisei_ai_passport';
  const sampleJson = '[{"id":"com.yourwish.ukalab.other","name":"うかラボ サンプル","tagline":"テスト用",'
      '"iconUrl":"","storeUrl":"https://example.com","category":"うかラボ"},'
      '{"id":"$appId","name":"自アプリ","tagline":"","iconUrl":"","storeUrl":"https://example.com","category":"うかラボ"}]';

  Future<void> pumpWidgetInList(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [w]))));
    await tester.pump();
  }

  testWidgets('掲載リストが空なら何も表示されず例外にならない', (tester) async {
    await pumpWidgetInList(tester, ukalabCrossPromoSectionForTest(currentAppId: appId, rawJson: '[]'));
    expect(find.text('他のアプリもチェック！'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Firebase 未初期化でも例外にならない（Remote Config 経由）', (tester) async {
    await pumpWidgetInList(tester, const UkalabCrossPromoSection(currentAppId: appId));
    expect(find.text('他のアプリもチェック！'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('掲載リストがあれば紹介カードを表示する', (tester) async {
    await pumpWidgetInList(tester, ukalabCrossPromoSectionForTest(currentAppId: appId, rawJson: sampleJson));
    expect(find.text('他のアプリもチェック！'), findsOneWidget);
    expect(find.text('うかラボ サンプル'), findsOneWidget);
    expect(find.text('自アプリ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('設定画面が Firebase 無しで例外なく表示される', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
          handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
          ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
          ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
          ...(await tester.runAsync(() => reminderOverrides('test')))!,
          ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
          dailyGoalAchievementsOverride,
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    // ListView は遅延構築なので、末尾付近まで スクロールして CrossPromoSection を構築させる。
    await tester.scrollUntilVisible(find.text('このアプリについて'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.byType(UkalabCrossPromoSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
