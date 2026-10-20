import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show BookmarkedQuestionsScreen, HomeSectionHeader, studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/core_features.dart';
import 'package:ukalab_seisei_ai_passport/screens/boundary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/glossary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mistake_note_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/reading_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/term_map_screen.dart';
import 'test_ads.dart';

ExamConfig _exam() => ExamConfig(
      examId: kExamId,
      name: '生成AIパスポート',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: const [],
    );

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(412, 900),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
    stubAdGateOverride(),
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
    ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
    ...(await tester.runAsync(() => reminderOverrides('test')))!,
    examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: HomeScreen(exam: _exam(), questionCount: 12)),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

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

/// 「学ぶ」タブ相当。[exam] を渡すと下に「道具」が出る。
Future<void> _pumpLearn(
  WidgetTester tester, {
  ExamConfig? exam,
  List<Question>? questions,
  int sessionSize = 10,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
    stubAdGateOverride(),
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
    ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
    ...(await tester.runAsync(() => reminderOverrides('test')))!,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: LearnScreen(
          questions: questions ?? [_q('q1'), _q('q2'), _q('q3')],
          sessionSize: sessionSize,
          exam: exam,
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Finder _header(String title) =>
    find.byWidgetPredicate((w) => w is HomeSectionHeader && w.title == title);

Future<void> _toggle(WidgetTester tester, String section) async {
  await tester.ensureVisible(_header(section));
  await tester.pump();
  await tester.tap(_header(section));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _open(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pump();
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

const _labTitles = ['推しの答案を添削', '学習の失敗図鑑', '境界線スライダー', '評価指標ラボ', '温度の実験室'];

/// 「学ぶ」の「道具」に移った入口の題名（ホームには出ない）。
const _movedTitles = ['間違いノート', 'ブックマーク', '自分用メモ', '用語集', '章ごとの解説読み物', '用語マップ', '今月のAI動向'];

void main() {
  testWidgets('ホームは4つの見出し（道具は無い）で、①②③は展開、体験ラボは畳まれている', (tester) async {
    await _pump(tester);
    for (final t in ['今日やること', '記録', '試験に向けて', '体験ラボ']) {
      expect(_header(t), findsOneWidget, reason: t);
    }
    expect(_header('道具'), findsNothing);
    expect(find.byType(HomeSectionHeader), findsNWidgets(4));
    expect(find.text('今日やる3つ'), findsOneWidget);
    expect(find.text('収録問題数'), findsOneWidget);
    expect(find.text('ながら学習'), findsOneWidget);
    expect(find.text('境界線スライダー'), findsNothing);
  });

  testWidgets('間違いノート・ブックマーク・メモ・用語集・読み物・用語マップ・AI動向はホームに無い', (tester) async {
    await _pump(tester);
    await _toggle(tester, '体験ラボ');
    for (final t in _movedTitles) {
      expect(find.text(t, skipOffstage: false), findsNothing, reason: t);
    }
  });

  testWidgets('体験ラボを開くと既存の入口がすべて見つかる', (tester) async {
    await _pump(tester);
    await _toggle(tester, '体験ラボ');
    for (final t in _labTitles) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: t);
    }
  });

  testWidgets('体験ラボの入口をタップすると遷移できる', (tester) async {
    await _pump(tester);
    await _toggle(tester, '体験ラボ');
    await _open(tester, '境界線スライダー');
    expect(find.byType(BoundaryScreen), findsOneWidget);
  });

  testWidgets('折りたたみの開閉が SharedPreferences に保存され、再表示で復元される', (tester) async {
    await _pump(tester);
    await _toggle(tester, '体験ラボ');
    expect(find.text('温度の実験室'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ukalab_seisei_home_section_lab'), isTrue);

    await _toggle(tester, '記録');
    expect(find.text('収録問題数'), findsNothing);
    expect(prefs.getBool('ukalab_seisei_home_section_record'), isFalse);

    await _pump(tester, prefs: {
      'ukalab_seisei_home_section_lab': true,
      'ukalab_seisei_home_section_record': false,
    });
    expect(find.text('温度の実験室'), findsOneWidget);
    expect(find.text('収録問題数'), findsNothing);
  });

  testWidgets('狭い幅+大きい文字でもオーバーフローしない', (tester) async {
    await _pump(tester,
        size: const Size(320, 640),
        textScale: 2.0,
        prefs: {'ukalab_seisei_home_section_lab': true});
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-grid-1')), findsWidgets);
  });

  group('「学ぶ」の「道具」', () {
    testWidgets('exam を渡すと演習の下に「道具」と全入口が出る', (tester) async {
      await _pumpLearn(tester, exam: _exam());
      expect(_header('道具'), findsOneWidget);
      for (final t in _movedTitles) {
        expect(find.text(t, skipOffstage: false), findsOneWidget, reason: t);
      }
      expect(find.textContaining('第1問'), findsOneWidget);
    });

    testWidgets('exam なし（弱点ドリルなど演習だけ）では「道具」を出さない', (tester) async {
      await _pumpLearn(tester);
      expect(_header('道具'), findsNothing);
      expect(find.text('用語集', skipOffstage: false), findsNothing);
      expect(find.text('間違いノート', skipOffstage: false), findsNothing);
    });

    testWidgets('結果表示でも「道具」が出る', (tester) async {
      await _pumpLearn(tester, exam: _exam(), questions: [_q('q1')], sessionSize: 1);
      await tester.tap(find.text('A').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('次へ'));
      await tester.tap(find.text('次へ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('次へ'), findsNothing);
      expect(_header('道具'), findsOneWidget);
      expect(find.text('用語集', skipOffstage: false), findsOneWidget);
    });

    testWidgets('問題が空でも「道具」が出る', (tester) async {
      await _pumpLearn(tester, exam: _exam(), questions: const []);
      expect(find.text('問題データがまだありません。'), findsOneWidget);
      expect(_header('道具'), findsOneWidget);
    });

    testWidgets('各入口から遷移できる（間違いノート・ブックマーク・用語集・読み物・用語マップ）', (tester) async {
      await _pumpLearn(tester, exam: _exam());
      Future<void> back() async {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await _open(tester, '間違いノート');
      expect(find.byType(MistakeNoteScreen), findsOneWidget);
      await back();

      await _open(tester, 'ブックマーク');
      expect(find.byType(BookmarkedQuestionsScreen), findsOneWidget);
      await back();

      await _open(tester, '用語集');
      expect(find.byType(GlossaryScreen), findsOneWidget);
      await back();

      await _open(tester, '章ごとの解説読み物');
      expect(find.byType(ReadingScreen), findsOneWidget);
      await back();

      await _open(tester, '用語マップ');
      expect(find.byType(TermMapScreen), findsOneWidget);
    });
  });
}
