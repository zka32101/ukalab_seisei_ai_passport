import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/answer_feedback.dart';
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';

Question _q(String qid) => Question(
      qid: qid,
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      prompt: '問題$qidの文',
      choices: const ['正解の選択肢', '誤りの選択肢'],
      answerIndex: 0,
      explanation: '解説$qid',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pumpLearn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
    ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
    ...(await tester.runAsync(() => reminderOverrides('test')))!,
    ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
    dailyGoalAchievementsOverride,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: LearnScreen(questions: [_q('a'), _q('b')], sessionSize: 2)),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(text));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('不正解だと原因パネルが出て、原因を選ぶと履歴に付く', (tester) async {
    final c = await _pumpLearn(tester);
    expect(find.text('知識不足'), findsNothing);

    await _tapAndSettle(tester, '誤りの選択肢');
    expect(find.byType(AnswerFeedbackPanel), findsOneWidget);
    expect(find.text('知識不足'), findsOneWidget);
    expect(c.read(historyProvider).single.cause, isNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('知識不足'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final rec = c.read(historyProvider).single;
    expect(rec.correct, isFalse);
    expect(rec.cause, WrongCause.knowledge);
    // 計算問題が無いので「計算ミス」は選べない。
    expect(find.text('計算ミス'), findsNothing);
  });

  testWidgets('正解では原因パネルの中身は出ない', (tester) async {
    final c = await _pumpLearn(tester);
    await _tapAndSettle(tester, '正解の選択肢');
    expect(find.text('知識不足'), findsNothing);
    expect(c.read(historyProvider).single.correct, isTrue);
  });
}
