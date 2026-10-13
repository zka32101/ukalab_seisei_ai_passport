import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/core_features.dart';
import 'package:ukalab_seisei_ai_passport/screens/exam_prep_entry.dart';

final _now = DateTime(2026, 11, 20, 12);

ExamConfig _exam() => ExamConfig(
      examId: kExamId,
      name: '生成AIパスポート',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: const [],
    );

Future<void> _pump(WidgetTester tester, {DateTime? date}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
  ]);
  addTearDown(container.dispose);
  if (date != null) await container.read(examDateProvider.notifier).setDate(date);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: ExamCountdownEntry(exam: _exam(), clock: () => _now)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('未設定なら何も出ない', (tester) async {
    await _pump(tester);
    expect(find.byType(ActionChip), findsNothing);
  });

  for (final c in {
    200: 'あと200日', // farAway
    60: 'あと60日', // approaching
    20: 'あと20日', // close
    3: 'あと3日', // finalDays
    0: '今日が試験日',
  }.entries) {
    testWidgets('${c.key}日後 -> ${c.value}', (tester) async {
      await _pump(tester, date: DateTime(2026, 11, 20 + c.key));
      expect(find.text(c.value), findsOneWidget);
    });
  }

  testWidgets('過ぎた日はおつかれさまでした(日数は出ない)', (tester) async {
    await _pump(tester, date: DateTime(2026, 11, 10));
    expect(find.text('おつかれさまでした'), findsOneWidget);
    expect(find.textContaining('あと'), findsNothing);
  });

  testWidgets('タップで試験日の設定画面が開く', (tester) async {
    await _pump(tester, date: DateTime(2026, 12, 20));
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.text('試験日の設定'), findsOneWidget);
    expect(find.byType(ExamDateTile), findsOneWidget);
  });
}
