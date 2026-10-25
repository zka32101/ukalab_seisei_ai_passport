import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/data/mistake_notes.dart';
import 'package:ukalab_seisei_ai_passport/data/srs_repository.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/nagara_entry.dart';
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

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

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home,
  FakeSpeechBackend speech,
) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    speechBackendProvider.overrideWithValue(speech),
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
    ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
    ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
    ...(await tester.runAsync(() => reminderOverrides('test')))!,
    ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
    dailyGoalAchievementsOverride,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: ListView(children: [home]))),
  ));
  await tester.pump();
  return container;
}

/// 画面を外して、ながらセッションのタイマーと読み上げを止める。
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  final questions = [_q('q1'), _q('q2'), _q('q3')];

  test('1回の上限問数は20問(プールが多くても20、少なければ全問)', () {
    expect(pickNagaraQuestions([for (var i = 0; i < 50; i++) _q('q$i')], seed: 1), hasLength(20));
    expect(pickNagaraQuestions(questions, seed: 1), hasLength(3));
    expect(pickNagaraQuestions(const []), isEmpty);
  });

  testWidgets('入口から開くと、問題を読み上げて始まる', (tester) async {
    final speech = FakeSpeechBackend()..holdUntilReleased = true;
    await _pump(tester, NagaraEntryCard(questions: questions), speech);
    await tester.tap(find.text('ながら学習'));
    await tester.pumpAndSettle();
    expect(find.byType(NagaraSessionView), findsOneWidget);
    expect(speech.spoken, isNotEmpty);
    expect(speech.spoken.first, contains('prompt-'));
    await _leave(tester);
  });

  /// 単問のプールでながらセッションを開き、[choice] をタップして、記録が済むまで待つ。
  Future<void> answerOnce(WidgetTester tester, ProviderContainer c, String choice) async {
    await tester.tap(find.text('ながら学習'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testWidgets('正答も誤答も1問1回ずつ、履歴と間隔反復に載る(二重に載らない)', (tester) async {
    final speech = FakeSpeechBackend()..holdUntilReleased = true;
    final one = [_q('q1')];
    final c = await _pump(tester, NagaraEntryCard(questions: one), speech);
    await tester.runAsync(() => c.read(historyProvider.notifier).ready);
    await tester.runAsync(() => c.read(srsProvider.future));

    await answerOnce(tester, c, 'machigai');
    expect(c.read(historyProvider).map((r) => r.correct), [false]);
    await answerOnce(tester, c, 'seikai');
    expect(c.read(historyProvider).map((r) => r.correct), [false, true]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    final stat = c.read(srsProvider).requireValue.stats['q1']!;
    expect(stat.attempts, 2);
    expect(stat.correct, 1);
    await _leave(tester);
  });

  testWidgets('スキップ・未回答は載らない', (tester) async {
    final speech = FakeSpeechBackend();
    final c = await _pump(tester, NagaraEntryCard(questions: [_q('q1'), _q('q2')]), speech);
    await tester.runAsync(() => c.read(historyProvider.notifier).ready);
    await tester.tap(find.text('ながら学習'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(NagaraStrings.ja.skip));
    await tester.pump();
    // 何も答えずに考える間・次の問題までの間が過ぎても、解答にはならない。
    await tester.pump(const Duration(seconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(c.read(historyProvider), isEmpty);
    await _leave(tester);
  });

  testWidgets('誤答のあと2回続けて正解すると、間違いノートで克服になる', (tester) async {
    final speech = FakeSpeechBackend()..holdUntilReleased = true;
    final one = [_q('q1')];
    final c = await _pump(tester, NagaraEntryCard(questions: one), speech);
    await tester.runAsync(() => c.read(historyProvider.notifier).ready);

    await answerOnce(tester, c, 'machigai');
    final afterWrong = mistakeNoteEngine.update(const [], c.read(historyProvider));
    expect(afterWrong.map((e) => e.qid), ['q1']);
    expect(afterWrong.single.overcome, isFalse);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await answerOnce(tester, c, 'seikai');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await answerOnce(tester, c, 'seikai');
    final after = mistakeNoteEngine.update(afterWrong, c.read(historyProvider));
    expect(after.single.overcome, isTrue);
    expect(mistakeNoteEngine.newlyOvercome(afterWrong, after), ['q1']);
    await _leave(tester);
  });

  testWidgets('停止で止まり、終了画面になる(以降は読み上げない)', (tester) async {
    final speech = FakeSpeechBackend()..holdUntilReleased = true;
    await _pump(tester, NagaraEntryCard(questions: questions), speech);
    await tester.tap(find.text('ながら学習'));
    await tester.pumpAndSettle();
    final before = speech.stopCount;

    await tester.tap(find.text(NagaraStrings.ja.stop));
    await tester.pump();
    expect(speech.stopCount, greaterThan(before));
    expect(find.text(NagaraStrings.ja.phaseFinished), findsOneWidget);

    final spokenAfterStop = speech.spoken.length;
    await tester.pump(const Duration(seconds: 60));
    expect(speech.spoken.length, spokenAfterStop);
    await _leave(tester);
  });

  testWidgets('設定: 考える間・次までの間・自動で次へ・解説を読むを保存し、反映する', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 't',
      packageName: 'com.yourwish.ukalab.seisei_ai_passport',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await _pump(tester, const SizedBox(height: 0), FakeSpeechBackend());
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ));
    await tester.pump();

    final t = NagaraStrings.ja;
    expect(find.text(t.settingsThinkSeconds), findsOneWidget);
    expect(find.text(t.settingsBetweenSeconds), findsOneWidget);
    expect(find.text(t.settingsAutoAdvance), findsOneWidget);
    expect(find.text('解説を読み上げる'), findsOneWidget);

    // 考える間: 5秒 -> 12秒
    await tester.tap(find.text('5秒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12秒').last);
    await tester.pumpAndSettle();
    expect(c.read(handsFreeProvider).thinkSeconds, 12);

    // 次の問題までの間: 2秒 -> 5秒
    await tester.tap(find.text('2秒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5秒').last);
    await tester.pumpAndSettle();
    expect(c.read(handsFreeProvider).betweenSeconds, 5);

    await tester.tap(find.text(t.settingsAutoAdvance));
    await tester.pump();
    expect(c.read(handsFreeProvider).autoAdvance, isFalse);

    await tester.tap(find.text('解説を読み上げる'));
    await tester.pump();
    expect(c.read(handsFreeProvider).speakExplanation, isFalse);
  });

  testWidgets('既存のハンズフリー出題画面(LearnScreen)は従来どおり出る', (tester) async {
    final speech = FakeSpeechBackend();
    final c = await _pump(tester, const SizedBox(height: 0), speech);
    await c.read(handsFreeProvider.notifier).setEnabled(true);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: LearnScreen(questions: questions))),
    ));
    await tester.pump();
    expect(find.byType(HandsFreeChoiceBody), findsOneWidget);
    await _leave(tester);
  });
}
