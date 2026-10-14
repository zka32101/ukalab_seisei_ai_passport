import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/exam_repository.dart';
import '../data/srs_repository.dart';
import 'learn_screen.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「記録」タブ: 間隔反復（Leitner方式）で復習時期が来た問題を表示する。
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examData = ref.watch(examDataProvider);
    final srs = ref.watch(srsProvider);

    if (examData.hasError || srs.hasError) {
      return const EmptyState(message: '記録を読み込めませんでした。');
    }
    final questions = examData.valueOrNull?.activeQuestions;
    final store = srs.valueOrNull;
    if (questions == null || store == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.items.isEmpty) {
      // 大きい文字・狭い幅では案内文が画面より縦に長くなるため、スクロールできるようにする。
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const EmptyState(
              icon: Icons.insights_outlined,
              message: '学習の記録はこれから。「学ぶ」タブで演習を進めると、ここに復習の予定が表示されます。',
            ),
          ),
        ),
      );
    }

    final byQid = {for (final q in questions) q.qid: q};
    final dueQuestions = [
      for (final item in store.due(DateTime.now()))
        if (byQid[item.qid] != null) byQid[item.qid]!,
    ];
    final subjectNames = {
      for (final s in examData.value!.exam.subjects) s.subjectId: s.name,
    };
    final weakSubjects = _weakSubjects(questions, store, subjectNames);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            dueQuestions.isEmpty ? '復習の予定はありません' : '復習の予定: ${dueQuestions.length}問',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '記録している問題: ${store.items.length}問（定着済み: ${store.masteredCount}問）',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (dueQuestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: wrappedAppBar(context, '復習'),
                    body: LearnScreen(
                      questions: questions,
                      priorityQids: [for (final q in dueQuestions) q.qid],
                      mode: PracticeMode.weak,
                    ),
                  ),
                ),
              ),
              child: const Text('復習を始める'),
            ),
          ],
          if (weakSubjects.isNotEmpty) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('苦手分野', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            for (final s in weakSubjects)
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: wrappedAppBar(context, '復習: ${s.name}'),
                      body: LearnScreen(
                        questions: questions,
                        priorityQids: _subjectReviewQids(questions, store, s.subjectId),
                        mode: PracticeMode.weak,
                      ),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.name, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      // 分野名が長い・文字が大きいときも右端が切れないよう、成績側も折り返せるようにする。
                      Flexible(
                        child: Text(
                          '${(s.accuracy * 100).round()}%（${s.correct}/${s.total}問）',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SubjectAccuracy {
  const _SubjectAccuracy({
    required this.subjectId,
    required this.name,
    required this.correct,
    required this.total,
  });

  final String subjectId;
  final String name;
  final int correct;
  final int total;

  double get accuracy => correct / total;
}

/// 解答済みの科目のうち、正答率が低い順に最大3件を返す。
List<_SubjectAccuracy> _weakSubjects(
  List<Question> questions,
  SrsStore store,
  Map<String, String> subjectNames,
) {
  final statsBySubject = store.statsBySubject(questions);
  final subjects = [
    for (final entry in statsBySubject.entries)
      _SubjectAccuracy(
        subjectId: entry.key,
        name: subjectNames[entry.key] ?? entry.key,
        correct: entry.value.$1,
        total: entry.value.$2,
      ),
  ]..sort((a, b) => a.accuracy.compareTo(b.accuracy));

  return subjects.take(3).toList();
}

/// ある科目で復習対象にする問題IDを返す。解答済みのうち不正解だったものを優先し、
/// 全問正解の科目では解答済み全問を対象にする。
List<String> _subjectReviewQids(
  List<Question> questions,
  SrsStore store,
  String subjectId,
) {
  final answeredQids = [
    for (final q in questions)
      if (q.subjectId == subjectId && store.stats.containsKey(q.qid)) q.qid,
  ];
  final incorrectQids = [
    for (final qid in answeredQids)
      if (store.stats[qid]!.correct < store.stats[qid]!.attempts) qid,
  ];
  return incorrectQids.isNotEmpty ? incorrectQids : answeredQids;
}
