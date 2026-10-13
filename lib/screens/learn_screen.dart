import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/answer_feedback.dart' show AnswerFeedbackPanel;
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/srs_repository.dart';

/// 「学ぶ」タブ: 短い演習セッション。解答ごとに間隔反復（記録タブ）の記録を更新する。
/// [priorityQids] を渡すと、その問題を先頭に出題する（記録タブからの復習呼び出し用）。
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({
    super.key,
    required this.questions,
    this.sessionSize = 10,
    this.priorityQids = const [],
    this.mode = PracticeMode.practice,
  });

  final List<Question> questions;
  final int sessionSize;
  final List<String> priorityQids;
  final PracticeMode mode;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  late PracticeSession _session = _newSession();
  // 表示中の問題。session.answer() は解答と同時に session.current を次の問題へ
  // 進めるため、解説・正誤表示には別途この値を使う（「次へ」が押されるまで保持）。
  late Question? _displayQuestion = _session.current;
  int? _selected;
  bool _answered = false;

  /// 出題を表示した時刻（回答にかかった時間の計測用）。
  DateTime _shownAt = DateTime.now();

  PracticeSession _newSession() {
    final size = widget.priorityQids.isEmpty
        ? widget.sessionSize.clamp(1, widget.questions.length)
        : widget.priorityQids.length.clamp(1, widget.questions.length);
    return PracticeSession(
      pool: widget.questions,
      size: size,
      mode: widget.mode,
      seed: DateTime.now().millisecondsSinceEpoch,
      priorityQids: widget.priorityQids,
    );
  }

  void _restart() {
    setState(() {
      _session = _newSession();
      _displayQuestion = _session.current;
      _selected = null;
      _answered = false;
      _shownAt = DateTime.now();
    });
  }

  void _select(int i) {
    if (_answered) return;
    final q = _displayQuestion!;
    setState(() {
      _selected = i;
      _answered = true;
    });
    _session.answer(i);
    ref
        .read(srsProvider.notifier)
        .recordAnswer(qid: q.qid, correct: i == q.answerIndex);
    recordDailyAnswer(ref);
    ref.read(historyProvider.notifier).record(
          q,
          correct: i == q.answerIndex,
          ms: DateTime.now().difference(_shownAt).inMilliseconds,
        );
  }

  void _next() {
    setState(() {
      _displayQuestion = _session.current;
      _selected = null;
      _answered = false;
      _shownAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const EmptyState(message: '問題データがまだありません。');
    }
    final q = _displayQuestion;
    if (q == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResultSummary(
            correct: _session.correctCount,
            total: _session.questions.length,
            onRetry: _restart,
          ),
        ),
      );
    }

    if (ref.watch(handsFreeProvider).enabled && !_answered) {
      return HandsFreeChoiceBody(
        qid: q.qid,
        prompt: q.prompt,
        choices: q.choices,
        index: _session.questions.indexOf(q) + 1,
        total: _session.questions.length,
        onSelect: _select,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: BookmarkToggleButton(qid: q.qid),
          ),
          QuestionCard(
            text: q.prompt,
            index: _session.questions.indexOf(q) + 1,
            total: _session.questions.length,
            child: Column(
              children: [
                for (var i = 0; i < q.choices.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  ChoiceTile(
                    label: String.fromCharCode(0x41 + i),
                    text: q.choices[i],
                    state: !_answered
                        ? (_selected == i ? ChoiceState.selected : ChoiceState.idle)
                        : (i == q.answerIndex
                            ? ChoiceState.correct
                            : (i == _selected ? ChoiceState.incorrect : ChoiceState.idle)),
                    onTap: () => _select(i),
                  ),
                ],
              ],
            ),
          ),
          if (_answered) ...[
            const SizedBox(height: 16),
            ExplanationPanel(
              body: q.explanation,
              sourceRef: q.sourceRef,
            ),
            const SizedBox(height: 12),
            // 不正解のときだけ表示される（原因ラベル・対策）。選択肢は並べ替えていないので元の番号のまま渡す。
            AnswerFeedbackPanel(
              key: ValueKey('feedback-${q.qid}'),
              question: q,
              selectedIndex: _selected,
              includeCalculation: false,
              onCause: (c) => ref.read(historyProvider.notifier).setCause(q.qid, c),
            ),
            const SizedBox(height: 12),
            QuestionMemoField(key: ValueKey(q.qid), qid: q.qid),
            const SizedBox(height: 16),
            FilledButton(onPressed: _next, child: const Text('次へ')),
          ],
        ],
      ),
    );
  }
}
