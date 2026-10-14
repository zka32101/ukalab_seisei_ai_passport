import 'package:app_common_kit/app_common_kit.dart'
    show
        FakeEntitlementService,
        InMemoryHandsFreeStore,
        entitlementServiceProvider,
        handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/core_features.dart';
import 'package:ukalab_seisei_ai_passport/data/oshi_recap.dart';
import 'package:ukalab_seisei_ai_passport/data/review_schedule.dart';
import 'package:ukalab_seisei_ai_passport/screens/core_v069_cards.dart' show OshiGrowthHomeCard;
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mistake_note_screen.dart';

Question _q(String qid) => Question(
  qid: qid,
  examId: kExamId,
  subjectId: 's1',
  topicId: 'ch1',
  prompt: '問題文-$qid',
  choices: const ['ア選択', 'イ選択'],
  answerIndex: 0,
  explanation: 'e',
  source: QuestionSource.original,
  sourceRef: '自作',
  contentVer: '1',
);

ExamConfig _exam() => ExamConfig(
  examId: kExamId,
  name: '生成AIパスポート',
  audience: Audience.adult,
  subjects: const [],
  levels: const [],
  examDates: const [],
);

ProgressRecord _rec(String qid, DateTime at, {bool correct = true}) =>
    ProgressRecord(
      qid: qid,
      subjectId: 's1',
      correct: correct,
      at: at,
      topicId: 'ch1',
    );

Future<void> _pump(
  WidgetTester tester, {
  List<ProgressRecord> history = const [],
  Map<String, Object> prefs = const {},
  Size size = const Size(412, 900),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({
    if (history.isNotEmpty)
      'ukalab_seisei_ai_passport_history_v1': encodeHistory(history),
    ...prefs,
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
      handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
      ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
      ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
      ...(await tester.runAsync(() => reminderOverrides('test')))!,
      examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: HomeScreen(
            exam: _exam(),
            questionCount: 3,
            questions: [_q('q1'), _q('q2'), _q('q3')],
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

int _dueShown(WidgetTester tester) =>
    tester.widget<TodayReviewCard>(find.byType(TodayReviewCard)).dueCount;

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day - n, 9);

  testWidgets('ホームに今日の復習・結果分析が出て、成長の吹き出しは出ない（履歴なし）', (tester) async {
    await _pump(tester);
    expect(find.byType(TodayReviewCard), findsOneWidget);
    expect(_dueShown(tester), 0);
    expect(find.byType(MockExamAnalysisCard), findsOneWidget);
    expect(find.byType(OshiGrowthHomeCard), findsOneWidget); // 祝福の見張り役は残す
    expect(find.byType(OshiGrowthBubble, skipOffstage: false), findsNothing);
    // 履歴が無ければ祝福は出ない。
    expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('間違いノートの期限分が件数に出て、開始で間違いノート画面に進む', (tester) async {
    await _pump(
      tester,
      history: [
        _rec('q1', daysAgo(3), correct: false),
        _rec('q2', daysAgo(2), correct: false),
        _rec('q3', daysAgo(2)),
      ],
    );
    expect(_dueShown(tester), 2);

    final start = find.descendant(
      of: find.byType(TodayReviewCard),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MistakeNoteScreen), findsOneWidget);
  });

  testWidgets('解答履歴があると結果分析に分野（科目）が出る', (tester) async {
    await _pump(
      tester,
      history: [
        for (var i = 0; i < 4; i++) _rec('q1', daysAgo(1), correct: i == 0),
      ],
    );
    final card = tester.widget<MockExamAnalysisCard>(
      find.byType(MockExamAnalysisCard),
    );
    expect(card.analysis.isEmpty, isFalse);
    expect(card.analysis.answered, 4);
  });

  testWidgets('節目（10問）に着いたら祝福が一度だけ出る', (tester) async {
    final history = [for (var i = 0; i < 10; i++) _rec('q1', daysAgo(0))];
    await _pump(tester, history: history);
    expect(find.byType(OshiGrowthCelebrationCard), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OshiGrowthCelebrationCard), findsNothing);

    // 記録済みなので、開き直しても出ない。
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('ukalab_oshi_growth_$kExamId'),
      contains('answered_10'),
    );
    await _pump(
      tester,
      history: history,
      prefs: {'ukalab_oshi_growth_$kExamId': '{"celebrated":["answered_10"]}'},
    );
    expect(find.byType(OshiGrowthCelebrationCard), findsNothing);
  });

  testWidgets('幅320・文字2倍でもオーバーフローしない（3カード表示）', (tester) async {
    await _pump(
      tester,
      size: const Size(320, 640),
      textScale: 2.0,
      history: [
        _rec('q1', daysAgo(3), correct: false),
        for (var i = 0; i < 3; i++) _rec('q2', daysAgo(1), correct: i == 0),
      ],
      prefs: {
        'ukalab_oshi_growth_$kExamId': '{"celebrated":["answered_10","days_7"]}',
      },
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TodayReviewCard), findsOneWidget);
    expect(
      find.byType(MockExamAnalysisCard, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(OshiGrowthBubble, skipOffstage: false), findsNothing);
  });

  group('recordReviewResult', () {
    final now = DateTime(2026, 10, 14, 12);
    ReviewItem item({required DateTime due}) => ReviewItem(
      qid: 'q1',
      stage: 0,
      dueAt: due,
      lastReviewedAt: DateTime(2026, 10, 10),
    );

    test('期限が来ている問題の正解で段が進む', () async {
      final store = InMemoryReviewSchedulerStore();
      await store.write([item(due: DateTime(2026, 10, 14))]);
      await recordReviewResult('q1', correct: true, at: now, store: store);
      expect((await store.read()).single.stage, 1);
    });

    test('期限前・対象外の問題は変えない', () async {
      final store = InMemoryReviewSchedulerStore();
      final before = [item(due: DateTime(2026, 10, 20))];
      await store.write(before);
      await recordReviewResult('q1', correct: true, at: now, store: store);
      await recordReviewResult('zzz', correct: true, at: now, store: store);
      expect(await store.read(), before);
    });
  });

  test('oshiGrowthProgressFor は回答数と学習日数（合計）を数える', () {
    final p = oshiGrowthProgressFor([
      _rec('q1', DateTime(2026, 10, 1, 9)),
      _rec('q2', DateTime(2026, 10, 1, 20)),
      _rec('q1', DateTime(2026, 10, 5, 9)),
    ]);
    expect(p.totalAnswered, 3);
    expect(p.studyDays, 2);
  });
}
