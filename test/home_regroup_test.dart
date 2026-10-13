import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_common_kit/app_common_kit.dart' show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/core_features.dart';
import 'package:ukalab_seisei_ai_passport/screens/boundary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/glossary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';

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

Future<void> _open(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

const _toolTitles = ['用語集', '章ごとの解説読み物', '用語マップ', '今月のAI動向'];
const _labTitles = ['推しの答案を添削', '学習の失敗図鑑', '境界線スライダー', '評価指標ラボ', '温度の実験室'];

void main() {
  testWidgets('6分類のうち5つの見出しが表示され、①②③は展開、④⑤は畳まれている', (tester) async {
    await _pump(tester);
    for (final t in ['今日やること', '記録', '試験に向けて', '道具', '体験ラボ']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('間違いノート'), findsOneWidget);
    expect(find.text('今日やる3つ'), findsOneWidget);
    expect(find.text('収録問題数'), findsOneWidget);
    expect(find.text('ながら学習'), findsOneWidget);
    expect(find.text('用語集'), findsNothing);
    expect(find.text('境界線スライダー'), findsNothing);
  });

  testWidgets('道具と体験ラボを開くと既存の入口がすべて見つかる', (tester) async {
    await _pump(tester);
    await _open(tester, '道具');
    await _open(tester, '体験ラボ');
    for (final t in [..._toolTitles, ..._labTitles]) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: t);
    }
  });

  testWidgets('入口をタップすると遷移できる（代表）', (tester) async {
    await _pump(tester);
    await _open(tester, '道具');
    await _open(tester, '用語集');
    expect(find.byType(GlossaryScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(GlossaryScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _open(tester, '体験ラボ');
    await tester.ensureVisible(find.text('境界線スライダー'));
    await _open(tester, '境界線スライダー');
    expect(find.byType(BoundaryScreen), findsOneWidget);
  });

  testWidgets('折りたたみの開閉が SharedPreferences に保存され、再表示で復元される', (tester) async {
    await _pump(tester);
    await _open(tester, '体験ラボ');
    expect(find.text('温度の実験室'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ukalab_seisei_home_section_lab'), isTrue);

    await _open(tester, '記録');
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
        prefs: {
          'ukalab_seisei_home_section_tools': true,
          'ukalab_seisei_home_section_lab': true,
        });
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-grid-1')), findsWidgets);
  });
}
