import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/review_schedule.dart';
import '../data/srs_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// ながらセッション1回あたりの上限問数(おつかれさまで区切る)。
const kNagaraSessionSize = 20;

/// 既存の出題選択([PracticeSession])で [pool] から [size] 問を選び、ながらセッション用に変換する。
List<NagaraQuestion> pickNagaraQuestions(
  List<Question> pool, {
  int size = kNagaraSessionSize,
  int? seed,
}) {
  if (pool.isEmpty) return const [];
  final session = PracticeSession(
    pool: pool,
    size: size.clamp(1, pool.length),
    mode: PracticeMode.practice,
    seed: seed ?? DateTime.now().millisecondsSinceEpoch,
  );
  return [
    for (final q in session.questions)
      NagaraQuestion(
        id: q.qid,
        prompt: q.prompt,
        choices: q.choices,
        correctIndex: q.answerIndex,
        explanation: q.explanation,
      ),
  ];
}

/// ホームに出す「ながら学習」の入口(1枚)。無料(core の [PremiumFeature] に該当なし)。
class NagaraEntryCard extends StatelessWidget {
  const NagaraEntryCard({super.key, required this.questions});

  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.headphones_outlined),
        title: const Text('ながら学習'),
        subtitle: const Text('問題と解説を読み上げながら、自動で進みます。画面をつけたままお使いください。'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openNagaraSession(context, questions),
      ),
    );
  }
}

void openNagaraSession(BuildContext context, List<Question> questions, {int? seed}) {
  final picked = pickNagaraQuestions(questions, seed: seed);
  if (picked.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('問題データがまだありません。')),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NagaraSessionScreen(questions: questions, picked: picked),
    ),
  );
}

/// ながらセッション画面。タップ解答(正答・誤答とも)は通常の解答と同じ経路(間隔反復・今日の目標・解答履歴)に載せる。
/// 解答履歴に載れば、間違いノートは開いたときに取り込む。
class NagaraSessionScreen extends ConsumerWidget {
  const NagaraSessionScreen({super.key, required this.questions, required this.picked});

  /// 出題元(qid から [Question] を引くため)。
  final List<Question> questions;
  final List<NagaraQuestion> picked;

  void _onAnswered(WidgetRef ref, NagaraQuestion nq, bool correct) {
    final matches = questions.where((q) => q.qid == nq.id);
    if (matches.isEmpty) return;
    final q = matches.first;
    ref.read(srsProvider.notifier).recordAnswer(qid: q.qid, correct: correct);
    recordDailyAnswer(ref);
    final at = DateTime.now();
    ref.read(historyProvider.notifier).record(q, correct: correct, at: at);
    recordReviewResult(q.qid, correct: correct, at: at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: wrappedAppBar(context, 'ながら学習'),
      body: NagaraSessionView(
        questions: picked,
        maxQuestions: kNagaraSessionSize,
        onAnswered: (nq, chosen, correct) => _onAnswered(ref, nq, correct),
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
