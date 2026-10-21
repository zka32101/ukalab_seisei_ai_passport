import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/coin_grants.dart';
import '../data/history_store.dart';
import '../data/oshi_recap.dart';
import 'settings_screen.dart';

/// ホームの「推しの一言」。学習状況(解答履歴・連続学習・試験日)から、責めない一言を出す。
/// タップで別の一言。無料。文言・選び方は ukalab_core。
class OshiMessageCard extends ConsumerWidget {
  const OshiMessageCard({super.key, required this.exam, this.clock = DateTime.now});

  final ExamConfig exam;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    // 過ぎた試験日は使わない。直近の未来の試験日だけ。
    final upcoming = effectiveExamDates(ref.watch(examDateProvider), exam.examDates)
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();
    final situation = oshiMessageContextFor(
      records: ref.watch(historyProvider),
      now: now,
      examDate: upcoming.isEmpty ? null : upcoming.first,
    );
    return OshiMessageBubble(situation: situation, now: now);
  }
}

/// ホームの「週間ふりかえり」。今週(月曜始まり)にできたことだけを見せる。無料。
/// 解いていない週は、責めずに穏やかな表示になる(core 側)。
class WeeklyRecapSection extends ConsumerWidget {
  const WeeklyRecapSection({
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
    return WeeklyRecapCard(
      recap: weeklyRecapFor(records: ref.watch(historyProvider), now: clock()),
      topicLabel: topicLabelFor(questions, (id) => exam.subject(id)?.name),
    );
  }
}

/// ホームの「推し」カード（共通キットの [UkalabOshiCard]）。
/// メニューから、推しの選択・着替え・ショップ・合格報告に入れる。コイン残高も出る。
/// 成長段階は解答履歴（解いた種類数・最新の正誤）から求める。
class OshiCard extends ConsumerWidget {
  const OshiCard({super.key, required this.exam, required this.totalQuestions, this.questions = const []});

  final ExamConfig exam;
  final int totalQuestions;

  /// 設定画面(履歴CSVの分野集計用)へ渡す出題元。
  final List<Question> questions;

  /// ロック中の資格専用キャラ(ヒラリ)のプレビューの「プレミアムを見る」から呼ばれる。
  /// 推しを選ぶ画面を閉じてから、購入欄(PurchaseSection)のある設定画面を開く。
  /// 下部タブはシェル(UkalabShell)の内部状態で外から切り替えられないため、設定画面を push する。
  static void openPurchase(BuildContext context, ExamConfig exam, List<Question> questions) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: SettingsScreen(questions: questions, exam: exam),
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = effectiveExamDates(ref.watch(examDateProvider), exam.examDates)
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();
    final records = ref.watch(historyProvider);
    final latest = <String, bool>{};
    for (final r in records) {
      latest[r.qid] = r.correct;
    }
    final mastery = totalQuestions <= 0 || latest.isEmpty
        ? const MasteryInput(coverage: 0, accuracy: 0)
        : MasteryInput(
            coverage: (latest.length / totalQuestions).clamp(0.0, 1.0),
            accuracy: latest.values.where((c) => c).length / latest.length,
          );
    final studiedToday = records.any((r) => DateTime(r.at.year, r.at.month, r.at.day) == today);
    return UkalabOshiCard(
      cert: UkalabCert.genAiPassport,
      stage: MasteryModel.standard.stageOf(mastery),
      appId: kCoinAppKey,
      examDate: upcoming.isEmpty ? null : upcoming.first,
      streakDays: currentStreakDays(records, now),
      studiedToday: studiedToday,
      onLockedTap: () => openPurchase(context, exam, questions),
    );
  }
}
