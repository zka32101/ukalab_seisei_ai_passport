import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/oshi_recap.dart';

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
