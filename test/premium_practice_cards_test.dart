import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/premium_practice_cards.dart';
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';

final _now = DateTime(2026, 11, 20, 12);

ExamConfig _exam({List<DateTime> dates = const []}) => ExamConfig(
      examId: 'seisei_ai_passport',
      name: '生成AIパスポート',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: dates,
    );

Question _q(String qid, {String topicId = 'ch1'}) => Question(
      qid: qid,
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: topicId,
      prompt: 'prompt-$qid',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool premium,
  required ExamConfig exam,
  List<Question>? questions,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
            ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
            ...(await tester.runAsync(() => reminderOverrides('test')))!,
            ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
            dailyGoalAchievementsOverride,
    entitlementStateProvider.overrideWith(
      (ref) => Stream.value(EntitlementState(hasPremium: premium)),
    ),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: PremiumPracticeCards(
          exam: exam,
          questions: questions ?? [_q('q1'), _q('q2')],
          clock: () => _now,
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('premiumでなければ、案内を出して画面には入らない', (tester) async {
    await _pump(tester, premium: false, exam: _exam());
    await tester.tap(find.text('弱点ドリル'));
    await tester.pump();
    expect(find.textContaining('プレミアムの機能'), findsOneWidget);
    expect(find.byType(LearnScreen), findsNothing);
  });

  testWidgets('premiumでも弱点が無ければ、案内を出す', (tester) async {
    await _pump(tester, premium: true, exam: _exam());
    await tester.tap(find.text('弱点ドリル'));
    await tester.pump();
    expect(find.textContaining('まだ弱点がありません'), findsOneWidget);
  });

  testWidgets('premiumで間違えた履歴があれば、弱点ドリルが始まる', (tester) async {
    final c = await _pump(tester, premium: true, exam: _exam());
    await c.read(historyProvider.notifier).record(_q('q1'), correct: false, at: _now);
    await tester.tap(find.text('弱点ドリル'));
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
  });

  testWidgets('試験日の3日前より前は、試験直前モードを出さない', (tester) async {
    await _pump(tester, premium: true, exam: _exam(dates: [DateTime(2026, 12, 20)]));
    expect(find.textContaining('試験直前モード'), findsNothing);
  });

  testWidgets('試験日の3日前以内なら、試験直前モードを出す', (tester) async {
    await _pump(tester, premium: true, exam: _exam(dates: [DateTime(2026, 11, 22)]));
    expect(find.textContaining('試験直前モード（あと2日）'), findsOneWidget);
  });

  testWidgets('利用者が入力した受験日が3日前以内なら、定義が空でも試験直前モードを出す', (tester) async {
    final c = await _pump(tester, premium: true, exam: _exam());
    await c.read(examDateProvider.notifier).setDate(DateTime(2026, 11, 22));
    await tester.pump();
    expect(find.textContaining('試験直前モード（あと2日）'), findsOneWidget);
  });

  testWidgets('利用者の受験日は、試験定義の日付より優先する', (tester) async {
    final c = await _pump(tester, premium: true, exam: _exam(dates: [DateTime(2026, 11, 22)]));
    await c.read(examDateProvider.notifier).setDate(DateTime(2026, 12, 20));
    await tester.pump();
    expect(find.textContaining('試験直前モード'), findsNothing);
  });

  testWidgets('受験日を解除すると保存値も消える', (tester) async {
    final c = await _pump(tester, premium: true, exam: _exam());
    await c.read(examDateProvider.notifier).setDate(DateTime(2026, 11, 22));
    await c.read(examDateProvider.notifier).setDate(null);
    expect(c.read(examDateProvider), isNull);
    await c.read(examDateProvider.notifier).load();
    expect(c.read(examDateProvider), isNull);
  });
}
