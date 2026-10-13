import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/core_features.dart';
import '../data/history_store.dart';
import 'learn_screen.dart';

/// ukalab_core の共通画面（`lib/ui/exam_prep/`）をこのアプリのデータにつなぐ部分。
/// 画面・文言は core 側。ここは取得・保存・premium 判定・遷移だけ。

bool isPremiumFor(WidgetRef ref, PremiumFeature feature) => canUsePremiumFeature(
      feature,
      isPremium: (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium,
    );

void _openPractice(BuildContext context, String title, List<Question> pool, String empty) {
  if (pool.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(empty)));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LearnScreen(questions: pool, sessionSize: pool.length),
    ),
  ));
}

/// ホームの「試験に向けて」カード（10分プラン・試験直前・当日チェックリスト）。
class ExamPrepEntryCard extends ConsumerWidget {
  const ExamPrepEntryCard({
    super.key,
    required this.exam,
    required this.questions,
    this.clock = DateTime.now,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = effectiveExamDates(ref.watch(examDateProvider), exam.examDates)
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();
    return ExamPrepCard(
      clock: clock,
      questions: () => questions,
      records: () => ref.read(historyProvider),
      examDate: upcoming.isEmpty ? null : upcoming.first,
      tenMinUnlocked: isPremiumFor(ref, PremiumFeature.tenMinutePlan),
      examEveUnlocked: isPremiumFor(ref, PremiumFeature.examEveMode),
      onStartPractice: _openPractice,
      onOpenChecklist: (c) async {
        final notifier = ref.read(checklistProvider.notifier);
        await notifier.ready;
        if (!c.mounted) return;
        final items = await loadChecklist();
        if (!c.mounted) return;
        await Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => ExamDayChecklistView(
            examId: kExamId,
            items: items,
            initialProgress: ref.read(checklistProvider),
            onChanged: notifier.setProgress,
          ),
        ));
      },
    );
  }
}

/// 設定タブの、更新ログ・履歴書き出しの入口。
class ExamPrepSettingsEntry extends ConsumerWidget {
  const ExamPrepSettingsEntry({super.key, this.questions = const []});

  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExamPrepSettingsTiles(
      exportUnlocked: isPremiumFor(ref, PremiumFeature.historyExport),
      onOpenUpdateLog: (c) => Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => UpdateLogView(entriesFuture: loadUpdateLog()))),
      onOpenExport: (c) => Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => HistoryExportView(records: ref.read(historyProvider), questions: questions))),
    );
  }
}
