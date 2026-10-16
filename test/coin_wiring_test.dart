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
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/exam_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mock_exam_screen.dart';
import 'test_ads.dart';

Question _q(String qid) => Question(
      qid: qid,
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      prompt: 'prompt-$qid',
      choices: const ['seikai', 'machigai'],
      answerIndex: 0,
      explanation: 'kaisetsu-$qid',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

late CoinService _coins;

Future<ProviderContainer> _pump(WidgetTester tester, Widget home, {bool withCoin = true}) async {
  SharedPreferences.setMockInitialValues({});
  _coins = CoinService(store: InMemoryCoinStore(), shop: OutfitCatalog.shopItems([UkalabCert.genAiPassport]));
  await tester.runAsync(_coins.load);
  final outfit = OutfitService(store: InMemoryOutfitStore());
  await tester.runAsync(outfit.load);
  final container = ProviderContainer(overrides: [
    if (withCoin) coinServiceProvider.overrideWithValue(_coins),
    if (withCoin) outfitServiceProvider.overrideWithValue(outfit),
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
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: home)),
  ));
  await tester.pump();
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump();
}

void main() {
  testWidgets('出題で初めて解くとコインが増え、同じ問題を解き直しても増えない', (tester) async {
    await _pump(tester, LearnScreen(questions: [_q('q1')], sessionSize: 1));
    expect(_coins.balance, 0);
    await tester.tap(find.text('machigai')); // 正誤不問
    await _settle(tester);
    final after = _coins.balance;
    expect(after, greaterThan(0));

    // 同じ問題をもう一度（やり直し）
    await tester.tap(find.text('次へ'));
    await tester.pump();
    await tester.tap(find.text('もう一度').evaluate().isNotEmpty ? find.text('もう一度') : find.byType(OutlinedButton).first);
    await tester.pump();
    await tester.tap(find.text('seikai'));
    await _settle(tester);
    expect(_coins.balance, after);
  });

  testWidgets('コインのサービスが未設定でも、出題は落ちずに進む', (tester) async {
    final c = await _pump(tester, LearnScreen(questions: [_q('q1')], sessionSize: 1), withCoin: false);
    await tester.tap(find.text('seikai'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('次へ'), findsOneWidget);
    await tester.runAsync(() => c.read(historyProvider.notifier).ready);
  });

  testWidgets('模擬試験を終えるとコイン、合格するとさらにコイン', (tester) async {
    final data = (await tester.runAsync(loadExamData))!;
    final qs = data.activeQuestions.take(5).toList();
    await _pump(tester, MockExamScreen(exam: data.exam, questions: qs));
    await tester.tap(find.text('模擬試験を始める'));
    await tester.pump();
    for (var i = 0; i < qs.length; i++) {
      final q = qs.firstWhere((q) => find.text(q.prompt).evaluate().isNotEmpty);
      await tester.tap(find.text(q.choices[q.answerIndex]).first);
      await tester.pump();
      await tester.tap(find.text(i + 1 < qs.length ? '次へ' : '結果を見る'));
      await tester.pump();
    }
    await _settle(tester);
    // mockDone(10) + mockPass(50)。量は core の規則に任せ、増えたことと内訳の種類を見る。
    final types = _coins.ledger.entries.map((e) => e.kind).toSet();
    expect(types, containsAll(['mockDone', 'mockPass']));
    expect(_coins.balance, greaterThan(0));
  });

  testWidgets('ホームの推しカードから着替え・ショップが空にならず開ける', (tester) async {
    final data = (await tester.runAsync(loadExamData))!;
    await _pump(
      tester,
      HomeScreen(exam: data.exam, questionCount: data.activeQuestions.length, questions: data.activeQuestions),
    );
    await _settle(tester);
    expect(find.byType(UkalabOshiCard), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<Object>).first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(PopupMenuItem<Object>, '着替え・ショップ'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(WardrobeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
