import 'dart:convert';
import 'dart:typed_data';

import 'package:app_common_kit/app_common_kit.dart'
    show
        EntitlementState,
        FakeEntitlementService,
        InMemoryHandsFreeStore,
        entitlementServiceProvider,
        handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show FileSaver, PremiumBenefitsCard, studyNotesOverrides;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/history_store.dart';
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

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

void _seedHistory(bool withRecord) {
  SharedPreferences.setMockInitialValues({
    if (withRecord)
      'ukalab_seisei_ai_passport_history_v1': encodeHistory([
        ProgressRecord(
          qid: 'q1',
          subjectId: 's1',
          correct: true,
          at: DateTime(2026, 10, 9, 10),
          topicId: 'ch1',
        ),
      ]),
  });
}

Future<void> _pump(
  WidgetTester tester, {
  EntitlementState entitlement = EntitlementState.free,
  FileSaver? saver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(FakeEntitlementService(initial: entitlement)),
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
        ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
        ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
        ...(await tester.runAsync(() => reminderOverrides('test')))!,
        ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
        dailyGoalAchievementsOverride,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            questions: [_q('q1')],
            saver: saver,
            now: () => DateTime(2026, 10, 20, 9),
          ),
        ),
      ),
    ),
  );
  // 履歴の読み込み(実際の非同期)をここで済ませる。
  final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
  await tester.runAsync(() => container.read(historyProvider.notifier).ready);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('PremiumBenefitsCard', () {
    testWidgets('無料のときは設定に出て、実装済みの機能だけを載せる', (tester) async {
      _seedHistory(false);
      await _pump(tester);
      expect(find.byType(PremiumBenefitsCard), findsOneWidget);
      expect(find.text('プレミアムでできること'), findsOneWidget);
      expect(find.byKey(const ValueKey('premiumBenefit_weakDrill')), findsOneWidget);
      expect(find.byKey(const ValueKey('premiumBenefit_readingReadAloud')), findsOneWidget);
      // このアプリに無いカスタム模擬試験は載せない。
      expect(find.byKey(const ValueKey('premiumBenefit_customMockExam')), findsNothing);
      final card = find.byType(PremiumBenefitsCard);
      expect(find.descendant(of: card, matching: find.textContaining('公式')), findsNothing);
      expect(find.descendant(of: card, matching: find.textContaining('合格保証')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('広告なしだけの購入者にはまだ出る', (tester) async {
      _seedHistory(false);
      await _pump(tester, entitlement: const EntitlementState(hasNoAds: true));
      expect(find.byType(PremiumBenefitsCard), findsOneWidget);
    });

    testWidgets('プレミアム購入者には出さない', (tester) async {
      _seedHistory(false);
      await _pump(tester, entitlement: const EntitlementState(hasPremium: true));
      expect(find.byType(PremiumBenefitsCard), findsNothing);
    });
  });

  group('学習履歴のCSV保存', () {
    Future<void> tapSave(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('saveHistoryCsv')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('saveHistoryCsv')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveHistoryCsv')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('shareCsv に UTF-8 BOM・text/csv・ukalab_history_YYYYMMDD.csv で渡し、個人情報の列を持たない', (tester) async {
      _seedHistory(true);
      final calls = <({Uint8List bytes, String name, String mime})>[];
      await _pump(tester, saver: ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async {
        calls.add((bytes: bytes, name: fileName, mime: mimeType));
        return true;
      });
      await tapSave(tester);

      expect(calls, hasLength(1));
      expect(calls.single.name, 'ukalab_history_20261020.csv');
      expect(calls.single.mime, 'text/csv');
      expect(calls.single.bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
      final csv = utf8.decode(calls.single.bytes.skip(3).toList());
      expect(csv, contains('日付,解答数,正答数,正答率(%),学習時間(分)'));
      expect(csv, contains('2026-10-09,1,1,100.0'));
      expect(csv, isNot(contains('q1')));
      expect(find.text('書き出しました'), findsOneWidget);
    });

    testWidgets('共有に失敗したら失敗の文言を出す', (tester) async {
      _seedHistory(true);
      await _pump(tester, saver: ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async =>
          throw StateError('x'));
      await tapSave(tester);
      expect(find.text('書き出せませんでした'), findsOneWidget);
    });

    testWidgets('履歴が空なら保存を呼ばず、空の文言を出す', (tester) async {
      _seedHistory(false);
      var called = false;
      await _pump(tester, saver: ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async {
        called = true;
        return true;
      });
      await tapSave(tester);
      expect(called, isFalse);
      expect(find.text('まだ書き出せる履歴がありません。解くとここに集まります。'), findsOneWidget);
    });
  });
}
