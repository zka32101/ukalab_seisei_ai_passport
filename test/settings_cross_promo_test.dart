import 'package:app_common_kit/app_common_kit.dart'
    show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:cross_promo_kit/cross_promo_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sample = [
    PromotedApp(
      id: 'com.example.ukalab.other',
      name: 'うかラボ サンプル',
      tagline: 'テスト用',
      iconUrl: '',
      storeUrl: 'https://example.com',
      category: 'うかラボ',
    ),
  ];

  // 設定画面とは別に CrossPromoSection 単体を表示する（Firebase 無し環境）。
  Future<void> pumpSection(WidgetTester tester, {List<PromotedApp>? apps}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CrossPromoSection(
                currentAppId: 'com.yourwish.ukalab.seisei_ai_passport',
                currentCategory: 'うかラボ',
                appsOverride: apps,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('掲載リストが空なら何も表示されず例外にならない', (tester) async {
    await pumpSection(tester, apps: const []);
    expect(find.text('他のアプリもチェック！'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Firebase 未初期化でも例外にならない（Remote Config 経由）', (tester) async {
    await pumpSection(tester);
    expect(find.text('他のアプリもチェック！'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('掲載リストがあれば紹介カードを表示する', (tester) async {
    await pumpSection(tester, apps: sample);
    expect(find.text('他のアプリもチェック！'), findsOneWidget);
    expect(find.text('うかラボ サンプル'), findsOneWidget);
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
    expect(find.byType(CrossPromoSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
