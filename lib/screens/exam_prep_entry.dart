import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/core_features.dart';
import '../data/history_store.dart';
import 'learn_screen.dart';
import '../widgets/wrapped_app_bar.dart';

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
      appBar: wrappedAppBar(context, title),
      body: LearnScreen(questions: pool, sessionSize: pool.length),
    ),
  ));
}

/// ホームの試験日カウントダウン(チップ)。未設定なら何も出ない。無料。
/// タップで試験日の設定を開く。文言・段階は ukalab_core(`ExamCountdownChip`)。
/// 直近の未来の試験日を使う。未来が無く、利用者が設定した日が過ぎているときだけ「おつかれさまでした」。
class ExamCountdownEntry extends ConsumerWidget {
  const ExamCountdownEntry({super.key, required this.exam, this.clock = DateTime.now});

  final ExamConfig exam;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final saved = ref.watch(examDateProvider);
    final upcoming = effectiveExamDates(saved, exam.examDates)
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();
    return Align(
      alignment: Alignment.centerLeft,
      child: ExamCountdownChip(
        examDate: upcoming.isEmpty ? saved : upcoming.first,
        clock: clock,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const ExamDateSettingsScreen(),
        )),
      ),
    );
  }
}

/// 試験日の設定だけを開く画面(設定タブと同じ `ExamDateTile`)。
class ExamDateSettingsScreen extends ConsumerWidget {
  const ExamDateSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: wrappedAppBar(context, '試験日の設定'),
      body: ListView(children: [
        ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
      ]),
    );
  }
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
