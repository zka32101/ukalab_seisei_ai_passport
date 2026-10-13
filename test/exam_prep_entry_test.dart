import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/core_features.dart';
import 'package:ukalab_seisei_ai_passport/data/data_parts.dart';
import 'package:ukalab_seisei_ai_passport/screens/exam_prep_entry.dart';

final _now = DateTime(2026, 11, 20, 12);

ExamConfig _exam({List<DateTime> dates = const []}) => ExamConfig(
      examId: kExamId,
      name: '生成AIパスポート',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: dates,
    );

Question _q(String qid) => Question(
      qid: qid,
      examId: kExamId,
      subjectId: 's1',
      topicId: 'ch1',
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
  bool premium = true,
  ExamConfig? exam,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    entitlementStateProvider.overrideWith((ref) => Stream.value(EntitlementState(hasPremium: premium))),
    examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ExamPrepEntryCard(exam: exam ?? _exam(), questions: [_q('q1'), _q('q2')], clock: () => _now),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  test('更新ログ・チェックリストの同梱データが読めて、検証を通る', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final log = await loadUpdateLog(now: DateTime(2026, 10, 14));
    expect(log, isNotEmpty);
    expect(log.first.date.isBefore(log.last.date), isFalse);
    final items = await loadChecklist();
    expect(items.length, greaterThanOrEqualTo(5));
    // 公式で確認できていない項目は、確認済みにしない（断定しない）
    expect(items.every((i) => !i.officialConfirmed), isTrue);
    expect(unconfirmedItems(items).length, items.length);
  });

  testWidgets('試験日が未設定なら、試験直前の行とチェックリストを出さない', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('tenMinPlanTile')), findsOneWidget);
    expect(find.byKey(const ValueKey('examEveTile')), findsNothing);
    expect(find.byKey(const ValueKey('checklistTile')), findsNothing);
  });

  testWidgets('試験日の3日前より前は、試験直前の行を出さない', (tester) async {
    await _pump(tester, exam: _exam(dates: [DateTime(2026, 12, 20)]));
    expect(find.byKey(const ValueKey('examEveTile')), findsNothing);
    expect(find.byKey(const ValueKey('checklistTile')), findsOneWidget);
  });

  testWidgets('試験日の3日前以内なら、試験直前とチェックリストを出す', (tester) async {
    await _pump(tester, exam: _exam(dates: [DateTime(2026, 11, 22)]));
    expect(find.byKey(const ValueKey('examEveTile')), findsOneWidget);
    expect(find.byKey(const ValueKey('checklistTile')), findsOneWidget);
  });

  testWidgets('利用者が入力した受験日は、試験定義の日付より優先する', (tester) async {
    final c = await _pump(tester, exam: _exam(dates: [DateTime(2026, 11, 22)]));
    await c.read(examDateProvider.notifier).setDate(DateTime(2026, 12, 20));
    await tester.pump();
    expect(find.byKey(const ValueKey('examEveTile')), findsNothing);
  });

  testWidgets('チェックリスト: チェックが保存され、バックアップ・リセット・復元できる', (tester) async {
    final c = await _pump(tester, exam: _exam(dates: [DateTime(2026, 11, 22)]));
    await tester.runAsync(() => c.read(checklistProvider.notifier).ready);
    await tester.tap(find.byKey(const ValueKey('checklistTile')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ExamDayChecklistView), findsOneWidget);
    expect(find.textContaining('公式で要確認'), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('ukalab_seisei_ai_passport_exam_checklist_v1'), hasLength(1));

    final part = seiseiDataParts.firstWhere((p) => p.id == 'examChecklist');
    late WidgetRef wref;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: Consumer(builder: (context, ref, _) {
        wref = ref;
        return const SizedBox();
      }),
    ));
    expect(part.export(wref), hasLength(1));
    await tester.runAsync(() => part.reset(wref));
    expect(c.read(checklistProvider).checkedIds, isEmpty);
    await tester.runAsync(() => part.restore(wref, ['a', 'b']));
    expect(c.read(checklistProvider).checkedIds, {'a', 'b'});
  });

  testWidgets('無料ユーザーは10分プランを開けず、案内だけ出る', (tester) async {
    await _pump(tester, premium: false);
    await tester.tap(find.byKey(const ValueKey('tenMinPlanTile')));
    await tester.pump();
    expect(find.textContaining('プレミアム'), findsWidgets);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('設定: 更新ログは無料で開ける。書き出しはpremiumのみ', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      entitlementStateProvider.overrideWith((ref) => Stream.value(const EntitlementState(hasPremium: false))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: ExamPrepSettingsEntry())),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exportTile')));
    await tester.pump();
    expect(find.byType(HistoryExportView), findsNothing);
    await tester.tap(find.byKey(const ValueKey('updateLogTile')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(UpdateLogView), findsOneWidget);
  });
}
