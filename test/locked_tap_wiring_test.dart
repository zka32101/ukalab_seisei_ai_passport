import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_seisei_ai_passport/data/character_wiring.dart';
import 'package:ukalab_seisei_ai_passport/data/exam_repository.dart';
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';
import 'test_ads.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final data = (await tester.runAsync(loadExamData))!;
  final coins = CoinService(store: InMemoryCoinStore(), shop: OutfitCatalog.shopItems([UkalabCert.genAiPassport]));
  await tester.runAsync(coins.load);
  final outfit = OutfitService(store: InMemoryOutfitStore());
  await tester.runAsync(outfit.load);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...characterOverrides,
      coinServiceProvider.overrideWithValue(coins),
      outfitServiceProvider.overrideWithValue(outfit),
      entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
      stubAdGateOverride(),
      handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
      examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
      ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
      ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
      ...(await tester.runAsync(() => reminderOverrides('test')))!,
      ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
      ...(await tester.runAsync(() => mockExamHistoryOverrides('test')))!,
      dailyGoalAchievementsOverride,
    ],
    child: MaterialApp(
      home: Scaffold(
        body: HomeScreen(exam: data.exam, questionCount: data.activeQuestions.length, questions: data.activeQuestions),
      ),
    ),
  ));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump();
}

/// 推しの絵などが動き続けるため pumpAndSettle は使わず、時間を区切って進める。
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('ホームの推しカードに onLockedTap が渡っている', (tester) async {
    await _pumpHome(tester);
    final card = tester.widget<UkalabOshiCard>(find.byType(UkalabOshiCard));
    expect(card.onLockedTap, isNotNull);
  });

  testWidgets('ロック中のヒラリの「プレミアムを見る」で、選択画面を閉じて設定(購入欄)が開く', (tester) async {
    await _pumpHome(tester);
    await tester.tap(find.byType(PopupMenuButton<Object>).first);
    await _frames(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, '推しを選ぶ'));
    await _frames(tester);
    expect(find.byType(CharacterSelectScreen), findsOneWidget);

    final hirari = find.text('ヒラリ').first;
    await tester.ensureVisible(hirari);
    await _frames(tester);
    await tester.tap(hirari);
    await _frames(tester);
    await tester.tap(find.text('プレミアムを見る'));
    await _frames(tester);

    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(PurchaseSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
