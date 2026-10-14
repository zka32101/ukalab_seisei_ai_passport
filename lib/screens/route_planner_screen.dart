import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/exam_repository.dart';
import '../data/srs_repository.dart';
import 'learn_screen.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「今日やる3つ」（最短ルートプランナー、型④、決定76・77）。残り日数・弱点・
/// 配点から、今日取り組むべき科目を3つ提案する。足切り未達の科目は最優先。
class RoutePlannerScreen extends ConsumerWidget {
  const RoutePlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examData = ref.watch(examDataProvider);
    final srs = ref.watch(srsProvider);

    if (examData.hasError || srs.hasError) {
      return Scaffold(
        appBar: wrappedAppBar(context, '今日やる3つ'),
        body: const EmptyState(message: '読み込めませんでした。'),
      );
    }
    final data = examData.valueOrNull;
    final store = srs.valueOrNull;
    if (data == null || store == null) {
      return Scaffold(
        appBar: wrappedAppBar(context, '今日やる3つ'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final questions = data.activeQuestions;
    final level = data.exam.levels.first;
    final statsBySubject = store.statsBySubject(questions);
    final progress = [
      for (final entry in statsBySubject.entries)
        SubjectProgress(
          subjectId: entry.key,
          accuracy: entry.value.$2 == 0 ? 0 : entry.value.$1 / entry.value.$2,
        ),
    ];
    final tasks = const RoutePlanner().plan(
      exam: data.exam,
      level: level,
      progress: progress,
    );
    final subjectNames = {
      for (final s in data.exam.subjects) s.subjectId: s.name,
    };

    return Scaffold(
      appBar: wrappedAppBar(context, '今日やる3つ'),
      // 大きい文字・狭い幅でも下が切れないよう、縦にスクロールできるようにする。
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RoutePlannerWidget(
          tasks: [
            for (final t in tasks)
              RouteTaskSpec(
                subjectId: t.subjectId,
                subjectName: subjectNames[t.subjectId] ?? t.subjectId,
                belowPassLine: t.belowPassLine,
              ),
          ],
          onTapTask: (subjectId) {
            final subjectQuestions =
                questions.where((q) => q.subjectId == subjectId).toList();
            if (subjectQuestions.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: wrappedAppBar(context, subjectNames[subjectId] ?? subjectId),
                  body: LearnScreen(questions: subjectQuestions),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
