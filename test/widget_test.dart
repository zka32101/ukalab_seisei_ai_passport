import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;

import 'package:ukalab_seisei_ai_passport/main.dart';

// rootBundle.loadString は大きなファイル（questions.jsonl）を compute()
// （別Isolate）でデコードする。widget test 環境でそれを待つには
// tester.runAsync() でラップしてポーリングする必要がある
// （実アプリでは問題にならない）。1つのテストプロセス内で compute() を
// 複数回呼ぶと稀にハングするため、アプリの起動は1テストにまとめている。
Future<void> _waitUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    if (tester.any(finder)) return;
  }
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ホーム表示→学ぶタブで演習→記録タブに復習予定が反映される',
    (WidgetTester tester) async {
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
          child: const UkalabSeiseiAiPassportApp(),
        ),
      );
      await tester.pump();

      final homeTitle = find.textContaining('収録問題数');
      await _waitUntilFound(tester, homeTitle);

      expect(find.textContaining('生成AIパスポート'), findsWidgets);
      expect(homeTitle, findsOneWidget);

      await tester.tap(find.text('学ぶ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('第1問'), findsOneWidget);

      // 選択肢Aを選んで解答する（正誤は問わない。間隔反復の記録に使われる）。
      await tester.tap(find.text('A').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('記録'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('記録している問題: 1問'), findsOneWidget);
      expect(find.text('苦手分野'), findsOneWidget);

      // 苦手分野の行をタップすると、その科目の復習セッションに遷移する。
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('復習:'), findsOneWidget);
      expect(find.textContaining('第1問'), findsOneWidget);

      // 解答実績がある状態でも模擬試験が正常に開始できる（苦手科目優先の重み付け）。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('模擬'));

      await tester.tap(find.text('模擬'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('模擬試験を始める'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('第1問'), findsOneWidget);

      // ホームタブから「推しの答案を添削」に遷移できる。
      await tester.tap(find.text('ホーム'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('推しの答案を添削'));
      await tester.pump();
      await tester.tap(find.text('推しの答案を添削'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('推しの答案を添削'), findsWidgets);
      expect(find.textContaining('1 / '), findsOneWidget);

      // ホームタブから「学習の失敗図鑑」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('学習の失敗図鑑'));

      await tester.tap(find.text('学習の失敗図鑑'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('学習の失敗図鑑'), findsWidgets);
      expect(find.textContaining('1 / '), findsOneWidget);

      // ホームタブから「用語マップ」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('用語マップ'));
      await tester.ensureVisible(find.text('用語マップ'));
      await tester.pump();

      await tester.tap(find.text('用語マップ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('用語マップ'), findsWidgets);

      // ホームタブから「境界線スライダー」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('境界線スライダー'));
      await tester.ensureVisible(find.text('境界線スライダー'));
      await tester.pump();

      await tester.tap(find.text('境界線スライダー'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('境界線スライダー'), findsWidgets);
      expect(find.textContaining('1 / '), findsOneWidget);

      // ホームタブから「評価指標ラボ」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('評価指標ラボ'));
      await tester.ensureVisible(find.text('評価指標ラボ'));
      await tester.pump();

      await tester.tap(find.text('評価指標ラボ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('評価指標ラボ'), findsWidgets);
      expect(find.textContaining('1 / '), findsOneWidget);

      // ホームタブから「温度の実験室」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('温度の実験室'));
      await tester.ensureVisible(find.text('温度の実験室'));
      await tester.pump();

      await tester.tap(find.text('温度の実験室'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('温度の実験室'), findsWidgets);
      expect(find.textContaining('1 / '), findsOneWidget);

      // ホームタブから「今日やる3つ」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('今日やる3つ'));
      await tester.ensureVisible(find.text('今日やる3つ'));
      await tester.pump();

      await tester.tap(find.text('今日やる3つ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('今日やる3つ'), findsWidgets);

      // ホームタブから「今月のAI動向」にも遷移できる。
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitUntilFound(tester, find.text('今月のAI動向'));
      await tester.ensureVisible(find.text('今月のAI動向'));
      await tester.pump();

      await tester.tap(find.text('今月のAI動向'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('今月のAI動向'), findsWidgets);
      expect(find.text('一次情報を見る'), findsWidgets);
    },
  );
}
