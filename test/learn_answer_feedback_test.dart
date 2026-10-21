import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/learning.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'test_ads.dart';

/// 選択式の解答直後に PracticeSession.current が次の問題へ進んでも、
/// 解説・正誤の表示が解答した問題のままであることの回帰テスト。
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

late StateSetter _rebuildParent;

Future<void> _pumpLearn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    stubAdGateOverride(),
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
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          _rebuildParent = setState;
          // 再描画のたびに新しい LearnScreen を渡す（State は保たれる）。
          return LearnScreen(questions: [_q('a'), _q('b')], sessionSize: 2);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(text));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

/// 出題順は乱数のため、いま表示中の問題 ID（a か b）と、もう一方を返す。
(String, String) _shown() =>
    find.text('問題aの文').evaluate().isNotEmpty ? ('a', 'b') : ('b', 'a');

void main() {
  testWidgets('解答直後は解答した問題の解説・正誤が出て、親を再描画しても変わらない', (tester) async {
    await _pumpLearn(tester);
    final (cur, other) = _shown();
    expect(find.text('解説$cur'), findsNothing);

    await _tapAndSettle(tester, '誤りの選択肢');
    expect(find.text('問題$curの文'), findsOneWidget);
    expect(find.text('解説$cur'), findsOneWidget);
    expect(find.text('解説$other'), findsNothing);
    expect(find.text('問題$otherの文'), findsNothing);

    // 解答後〜「次へ」の間に親が再描画されても、表示中の問題は上書きされない。
    _rebuildParent(() {});
    await tester.pumpAndSettle();
    expect(find.text('問題$curの文'), findsOneWidget);
    expect(find.text('解説$cur'), findsOneWidget);
    expect(find.text('解説$other'), findsNothing);
    expect(find.text('問題$otherの文'), findsNothing);
    expect(find.text('次へ'), findsOneWidget);
  });

  testWidgets('「次へ」で次の問題に進み、最後の問題は解説を見てから結果画面へ移る', (tester) async {
    await _pumpLearn(tester);
    final (first, second) = _shown();

    await _tapAndSettle(tester, '正解の選択肢');
    _rebuildParent(() {});
    await tester.pumpAndSettle();
    expect(find.text('解説$first'), findsOneWidget);
    expect(find.byType(ResultSummary), findsNothing);

    await _tapAndSettle(tester, '次へ');
    expect(find.text('問題$secondの文'), findsOneWidget);
    expect(find.text('問題$firstの文'), findsNothing);
    expect(find.text('解説$first'), findsNothing);
    expect(find.text('解説$second'), findsNothing);

    // 最後の問題: 解答しても結果画面にならず、解説が出る。
    await _tapAndSettle(tester, '正解の選択肢');
    _rebuildParent(() {});
    await tester.pumpAndSettle();
    expect(find.byType(ResultSummary), findsNothing);
    expect(find.text('解説$second'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);

    await _tapAndSettle(tester, '次へ');
    expect(find.byType(ResultSummary), findsOneWidget);
    expect(find.text('解説$second'), findsNothing);
  });
}
