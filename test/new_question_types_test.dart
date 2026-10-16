import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/exam_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/feature_flags.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/nagara_entry.dart';

// 新タイプの問題はテスト内の最小フィクスチャ（出荷する assets には入れない）。

Question _choice(String id) => Question(
      qid: id,
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      prompt: '選択式$id',
      choices: ['$idの正解', '$idの誤り'],
      answerIndex: 0,
      explanation: '$idの解説',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Question _tf() => Question(
      qid: 'tf1',
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      type: QuestionType.trueFalse,
      prompt: '過学習は訓練データへ過剰に適合する現象である。',
      answerBool: true,
      explanation: 'tf1の解説文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Question _cloze() => Question(
      qid: 'cz1',
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      type: QuestionType.cloze,
      prompt: '{{1}}は訓練データに適合しすぎる現象である。',
      blanks: const [ClozeBlank(id: 1, answers: ['過学習'])],
      explanation: 'cz1の解説文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Question _rev() => Question(
      qid: 'rv1',
      examId: 'seisei_ai_passport',
      subjectId: 's1',
      topicId: 'ch1',
      type: QuestionType.reverseLookup,
      prompt: '次の説明に当てはまる用語は何か。',
      clue: '訓練データに過剰に適合し汎化性能が下がる現象',
      answers: const ['過学習'],
      choices: const ['過学習', '正則化', '汎化', '転移学習'],
      explanation: 'rv1の解説文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

List<Question> _mixed() => [_choice('c1'), _tf(), _cloze(), _rev()];

ExamData _examData(List<Question> qs, {bool? enabled}) => ExamData(
      exam: const ExamConfig(
        examId: 'seisei_ai_passport',
        name: '生成AIパスポート',
        audience: Audience.adult,
        subjects: [],
        levels: [],
        examDates: [],
      ),
      questions: qs,
      newQuestionTypesEnabled: enabled ?? kNewQuestionTypesEnabled,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<Question> qs, {
  required bool newTypesEnabled,
  int? size,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
      home: Scaffold(
        body: LearnScreen(
          questions: qs,
          sessionSize: size ?? qs.length,
          newTypesEnabled: newTypesEnabled,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('フラグ（既定 OFF）', () {
    test('既定は OFF で、模擬試験の許可タイプは core 既定の4タイプ', () {
      expect(kNewQuestionTypesEnabled, isFalse);
      expect(kMockExamAllowedTypes, defaultMockExamTypes);
      expect(kMockExamAllowedTypes.contains(QuestionType.trueFalse), isFalse);
      expect(kMockExamAllowedTypes.contains(QuestionType.cloze), isFalse);
      expect(kMockExamAllowedTypes.contains(QuestionType.reverseLookup), isFalse);
    });

    test('OFF: 新タイプは出題プールから除かれ、選択式は順序どおり残る', () {
      expect(selectableQuestions(_mixed(), newTypesEnabled: false).map((q) => q.qid), ['c1']);
      expect(
        selectableQuestions([_choice('a'), _choice('b')], newTypesEnabled: false).map((q) => q.qid),
        ['a', 'b'],
      );
    });

    test('ON: 新タイプも含む', () {
      expect(selectableQuestions(_mixed(), newTypesEnabled: true).map((q) => q.qid),
          ['c1', 'tf1', 'cz1', 'rv1']);
    });

    test('ExamData.activeQuestions: 既定（OFF）では新タイプが出ない / ON で出る', () {
      final qs = _mixed();
      expect(_examData(qs).activeQuestions.map((q) => q.qid), ['c1']);
      expect(_examData(qs, enabled: false).activeQuestions.map((q) => q.qid), ['c1']);
      expect(_examData(qs, enabled: true).activeQuestions.map((q) => q.qid),
          ['c1', 'tf1', 'cz1', 'rv1']);
    });

    test('模擬試験: 許可タイプでは新タイプが出ない', () {
      expect(mockExamEligible(_mixed()).map((q) => q.qid), ['c1']);
      final picked = pickCustomMockExamQuestions(
        pool: _mixed(),
        subjectIds: const ['s1'],
        count: 10,
        allowedTypes: kMockExamAllowedTypes,
      );
      expect(picked.map((q) => q.qid), ['c1']);
    });

    test('ながらセッション: フラグに関わらず新タイプを除く', () {
      final out = pickNagaraQuestions(_mixed(), seed: 1);
      expect(out.map((n) => n.id), ['c1']);
      expect(pickNagaraQuestions([_tf(), _cloze(), _rev()]), isEmpty);
    });

    testWidgets('OFF: 演習に新タイプだけを渡しても出ない（空表示）', (tester) async {
      await _pump(tester, [_tf(), _cloze(), _rev()], newTypesEnabled: false);
      expect(find.text('問題データがまだありません。'), findsOneWidget);
      expect(find.byType(TrueFalseQuestionView), findsNothing);
    });

    testWidgets('OFF: 選択式との混在でも選択式だけが出る', (tester) async {
      await _pump(tester, _mixed(), newTypesEnabled: false, size: 10);
      expect(find.text('選択式c1'), findsOneWidget);
      expect(find.byType(TrueFalseQuestionView), findsNothing);
    });
  });

  group('履歴の自己申告補正', () {
    test('直近の不正解を正解に直し、原因を外す。正解済み・無い qid は変えない', () {
      final at = DateTime(2026, 10, 1);
      final recs = [
        ProgressRecord(qid: 'a', subjectId: 's', correct: false, at: at, cause: WrongCause.misread),
        ProgressRecord(qid: 'b', subjectId: 's', correct: false, at: at),
      ];
      final out = markLatestRecordCorrect(recs, 'a');
      expect(out[0].correct, isTrue);
      expect(out[0].cause, isNull);
      expect(out[1].correct, isFalse);
      expect(markLatestRecordCorrect(out, 'a'), same(out));
      expect(markLatestRecordCorrect(recs, 'zzz'), same(recs));
    });
  });

  group('演習（フラグ ON）', () {
    testWidgets('○×: 間違えると履歴に不正解で残り、解説が出る', (tester) async {
      final c = await _pump(tester, [_tf()], newTypesEnabled: true);
      expect(find.byType(TrueFalseQuestionView), findsOneWidget);
      await tester.tap(find.textContaining('誤り').first); // × を選ぶ（正解は○）
      await _settle(tester);
      final h = c.read(historyProvider);
      expect(h.length, 1);
      expect(h.single.qid, 'tf1');
      expect(h.single.correct, isFalse);
      expect(find.text('tf1の解説文'), findsOneWidget);
    });

    testWidgets('○×: 正解は正解として記録される', (tester) async {
      final c = await _pump(tester, [_tf()], newTypesEnabled: true);
      await tester.tap(find.textContaining('正しい').first);
      await _settle(tester);
      expect(c.read(historyProvider).single.correct, isTrue);
    });

    testWidgets('空欄補充: 正解入力は正解として記録される', (tester) async {
      final c = await _pump(tester, [_cloze()], newTypesEnabled: true);
      expect(find.byType(ClozeQuestionView), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '過学習');
      await tester.pump();
      await tester.tap(find.text('解答する'));
      await _settle(tester);
      expect(c.read(historyProvider).single.correct, isTrue);
    });

    testWidgets('説明から用語（選択肢つき）: 選ぶと採点され記録される', (tester) async {
      final c = await _pump(tester, [_rev()], newTypesEnabled: true);
      expect(find.byType(ReverseLookupQuestionView), findsOneWidget);
      await tester.tap(find.text('正則化'));
      await _settle(tester);
      expect(c.read(historyProvider).single.qid, 'rv1');
      expect(c.read(historyProvider).single.correct, isFalse);
    });
  });
}
