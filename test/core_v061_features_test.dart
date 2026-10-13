import 'package:app_common_kit/app_common_kit.dart'
    show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/data_parts.dart';
import 'package:ukalab_seisei_ai_passport/data/mistake_notes.dart';
import 'package:ukalab_seisei_ai_passport/data/oshi_recap.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mistake_note_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/oshi_home_cards.dart';
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

// 2026-10-14 は水曜。月曜始まりの今週は 10/12〜10/18。
final _now = DateTime(2026, 10, 14, 12);

Question _q(String qid) => Question(
      qid: qid,
      examId: 'seisei_ai_passport',
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
      examId: 'seisei_ai_passport',
      name: '生成AIパスポート',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: const [],
    );

ProgressRecord _rec(String qid, DateTime at, {bool correct = true}) => ProgressRecord(
      qid: qid,
      subjectId: 's1',
      correct: correct,
      at: at,
      topicId: 'ch1',
    );

void _seedHistory(List<ProgressRecord> records) {
  SharedPreferences.setMockInitialValues({
    if (records.isNotEmpty) 'ukalab_seisei_ai_passport_history_v1': encodeHistory(records),
  });
}

Future<List<Override>> _overrides(WidgetTester tester) async => [
      entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
      handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
      examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
      ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
      ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
      ...(await tester.runAsync(() => reminderOverrides('test')))!,
      ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
      dailyGoalAchievementsOverride,
    ];

/// 履歴の読み込み(実際の非同期)を待ってから描画に反映する。
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(ProviderScope(
    overrides: await _overrides(tester),
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await _settle(tester);
}

void main() {
  group('入力の作り方(推しの一言)', () {
    test('履歴も試験日もなければ、最小の状況になる', () {
      final c = oshiMessageContextFor(records: const [], now: _now);
      expect(c.daysSinceLastStudy, isNull);
      expect(c.streakDays, 0);
      expect(c.todayAnswered, 0);
      expect(c.todayCorrectRate, isNull);
      expect(c.examDaysLeft, isNull);
      expect(c.hasWeakTopics, isFalse);
    });

    test('今日の解答数・正答率・最終学習からの日数・連続日数・試験日・苦手が反映される', () {
      final records = [
        _rec('a', DateTime(2026, 10, 13, 9)),
        _rec('b', DateTime(2026, 10, 14, 9)),
        _rec('c', DateTime(2026, 10, 14, 10)),
        _rec('d', DateTime(2026, 10, 14, 11), correct: false),
      ];
      final c = oshiMessageContextFor(
        records: records,
        now: _now,
        examDate: DateTime(2026, 11, 13),
      );
      expect(c.daysSinceLastStudy, 0);
      expect(c.streakDays, 2);
      expect(c.todayAnswered, 3);
      expect(c.todayCorrectRate, closeTo(2 / 3, 1e-9));
      expect(c.examDaysLeft, 30);
      expect(c.hasWeakTopics, isTrue);
    });

    test('久しぶりのときは連続日数を使わない。過ぎた試験日は渡さない', () {
      final c = oshiMessageContextFor(
        records: [
          _rec('a', DateTime(2026, 10, 7, 9)),
          _rec('b', DateTime(2026, 10, 8, 9)),
          _rec('c', DateTime(2026, 10, 9, 9)),
        ],
        now: _now,
        examDate: DateTime(2026, 10, 1),
      );
      expect(c.daysSinceLastStudy, 5);
      expect(c.streakDays, 0);
      expect(c.examDaysLeft, isNull);
    });

    test('連続日数: 昨日までの連続は続いている。間が空けば途切れた分は数えない', () {
      expect(
        currentStreakDays([
          _rec('a', DateTime(2026, 10, 10, 9)),
          _rec('b', DateTime(2026, 10, 12, 9)),
          _rec('c', DateTime(2026, 10, 13, 9)),
        ], _now),
        2,
      );
    });

    test('分野の表示名は、その問題の科目名になる(無ければID)', () {
      final label = topicLabelFor([_q('a')], (id) => id == 's1' ? '生成AIの基礎' : null);
      expect(label('ch1'), '生成AIの基礎');
      expect(label('unknown'), 'unknown');
    });
  });

  group('推しの一言(ホーム)', () {
    testWidgets('履歴なし: あいさつが出る', (tester) async {
      _seedHistory(const []);
      await _pump(tester, OshiMessageCard(exam: _exam(), clock: () => _now));
      expect(find.byType(OshiMessageBubble), findsOneWidget);
      final greetings = OshiMessageStrings.ja.variants(OshiSituation.greeting);
      expect(greetings.any((g) => find.text(g).evaluate().isNotEmpty), isTrue);
    });

    testWidgets('履歴あり(5日空いた): おかえりの一言が出る', (tester) async {
      _seedHistory([_rec('a', DateTime(2026, 10, 9, 9))]);
      await _pump(tester, OshiMessageCard(exam: _exam(), clock: () => _now));
      final texts = OshiMessageStrings.ja.variants(OshiSituation.welcomeBack);
      expect(texts.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });

    testWidgets('今日たくさん解いた: 達成の一言が出る(久しぶりにはならない)', (tester) async {
      _seedHistory([for (var i = 0; i < 4; i++) _rec('q$i', DateTime(2026, 10, 14, 9, i))]);
      await _pump(tester, OshiMessageCard(exam: _exam(), clock: () => _now));
      final texts = OshiMessageStrings.ja.variants(OshiSituation.praise);
      expect(texts.any((t) => find.text(t).evaluate().isNotEmpty), isTrue);
    });
  });

  group('週間ふりかえり(ホーム)', () {
    final strings = WeeklyRecapStrings.ja;

    testWidgets('今週解いていれば、できたことが出る', (tester) async {
      _seedHistory([
        _rec('a', DateTime(2026, 10, 12, 9)),
        _rec('b', DateTime(2026, 10, 14, 9)),
        _rec('c', DateTime(2026, 10, 14, 10), correct: false),
      ]);
      await _pump(
          tester, WeeklyRecapSection(exam: _exam(), questions: [_q('a')], clock: () => _now));
      expect(find.text(strings.title), findsOneWidget);
      expect(find.text(strings.emptyTitle), findsNothing);
      expect(find.textContaining('3${strings.questionsUnit}'), findsWidgets);
    });

    testWidgets('履歴なしの週(0件)は、責めずに「ひと休み」の表示', (tester) async {
      _seedHistory(const []);
      await _pump(
          tester, WeeklyRecapSection(exam: _exam(), questions: const [], clock: () => _now));
      expect(find.text(strings.emptyTitle), findsOneWidget);
    });

    testWidgets('先週だけ解いていた場合も、今週は0件として穏やかに表示する', (tester) async {
      _seedHistory([_rec('a', DateTime(2026, 10, 8, 9))]);
      await _pump(
          tester, WeeklyRecapSection(exam: _exam(), questions: [_q('a')], clock: () => _now));
      expect(find.text(strings.emptyTitle), findsOneWidget);
    });
  });

  group('間違いノート', () {
    final strings = MistakeNoteStrings.ja;

    Future<void> pumpScreen(WidgetTester tester, MistakeNoteStore store,
        {List<Question>? questions, List<ProgressRecord> history = const []}) async {
      _seedHistory(history);
      await tester.pumpWidget(ProviderScope(
        overrides: await _overrides(tester),
        child: MaterialApp(
          home: MistakeNoteScreen(
            exam: _exam(),
            questions: questions ?? [_q('q1'), _q('q2')],
            store: store,
          ),
        ),
      ));
      await _settle(tester);
    }

    testWidgets('間違えた問題が一覧に出る(正解だけの問題は出ない)', (tester) async {
      final store = InMemoryMistakeNoteStore();
      await pumpScreen(tester, store, history: [
        _rec('q1', DateTime(2026, 10, 14, 9), correct: false),
        _rec('q2', DateTime(2026, 10, 14, 10)),
      ]);
      expect(find.text('問題文-q1'), findsOneWidget);
      expect(find.text('問題文-q2'), findsNothing);
      expect(find.text(strings.retry), findsOneWidget);
      // 履歴から取り込んだ内容が保存される
      expect((await store.read()).map((e) => e.qid), ['q1']);
    });

    testWidgets('履歴なし: これからが空のメッセージ', (tester) async {
      await pumpScreen(tester, InMemoryMistakeNoteStore());
      expect(find.text(strings.emptyUpcomingTitle), findsOneWidget);
    });

    testWidgets('出題データに無い問題は出さない', (tester) async {
      await pumpScreen(tester, InMemoryMistakeNoteStore(),
          history: [_rec('gone', DateTime(2026, 10, 14, 9), correct: false)]);
      expect(find.text(strings.retry), findsNothing);
      expect(find.text(strings.emptyUpcomingTitle), findsOneWidget);
    });

    testWidgets('解き直す: 既存の演習画面がその問題で開き、解いて戻るとノートに反映される', (tester) async {
      final store = InMemoryMistakeNoteStore();
      await pumpScreen(tester, store,
          // 演習画面は現在時刻で記録するため、間違いは十分過去の日時にしておく。
          history: [_rec('q1', DateTime(2020, 1, 1, 9), correct: false)]);

      await tester.tap(find.text(strings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(LearnScreen), findsOneWidget);
      final learn = tester.widget<LearnScreen>(find.byType(LearnScreen));
      expect(learn.questions.map((q) => q.qid), ['q1']);
      expect(learn.sessionSize, 1);
      expect(find.text('問題文-q1'), findsWidgets);

      // 正解すると通常の履歴に記録され(演習画面の既存の動き)、戻ったときにノートへ取り込まれる
      await tester.tap(find.text('ア選択'));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byType(LearnScreen), findsNothing);
      expect(find.text('問題文-q1'), findsOneWidget);
      final saved = (await tester.runAsync(store.read))!;
      expect(saved.single.qid, 'q1');
      expect(saved.single.correctStreak, 1);
      expect(saved.single.overcome, isFalse);
    });
  });

  group('間違いノート: バックアップ・リセット', () {
    testWidgets('データの管理に mistakeNotes が登録され、書き出し・リセット・読み込みができる',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      late WidgetRef wref;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(builder: (context, ref, _) {
          wref = ref;
          return const SizedBox.shrink();
        }),
      ));
      final part = seiseiDataParts.firstWhere((p) => p.id == 'mistakeNotes');
      final entry = MistakeNoteEntry(
        qid: 'q1',
        firstMissedAt: DateTime(2026, 10, 14),
        lastMissedAt: DateTime(2026, 10, 14),
        missCount: 1,
        overcome: false,
        topicId: 'ch1',
        correctStreak: 0,
        lastAnsweredAt: DateTime(2026, 10, 14),
      );
      await tester.runAsync(() async {
        await mistakeNoteStore.write([entry]);
        final exported = await part.export(wref);
        expect(exported, isA<List>());
        expect((exported as List), hasLength(1));

        await part.reset(wref);
        expect(await mistakeNoteStore.read(), isEmpty);

        await part.restore(wref, exported);
        final restored = await mistakeNoteStore.read();
        expect(restored.single.qid, 'q1');
        expect(restored.single.topicId, 'ch1');
      });
    });
  });

  group('間違いノート: 設定からの入口', () {
    testWidgets('設定に間違いノートが出て、開ける', (tester) async {
      _seedHistory(const []);
      await tester.pumpWidget(ProviderScope(
        overrides: await _overrides(tester),
        child: MaterialApp(
          home: Scaffold(body: SettingsScreen(exam: _exam(), questions: [_q('q1')])),
        ),
      ));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text('間違いノート'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('間違いノート'));
      await tester.pumpAndSettle();
      expect(find.byType(MistakeNoteScreen), findsOneWidget);
    });

    testWidgets('exam を渡さない既存の使い方では、入口を出さない', (tester) async {
      _seedHistory(const []);
      await tester.pumpWidget(ProviderScope(
        overrides: await _overrides(tester),
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ));
      await _settle(tester);
      expect(find.text('間違いノート'), findsNothing);
    });
  });
}
