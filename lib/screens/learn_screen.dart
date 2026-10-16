import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/answer_feedback.dart' show AnswerFeedbackPanel;
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/coin_grants.dart';
import '../data/feature_flags.dart';
import '../data/history_store.dart';
import '../data/review_schedule.dart';
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
    this.newTypesEnabled = kNewQuestionTypesEnabled,
  });

  final List<Question> questions;
  final int sessionSize;
  final List<String> priorityQids;
  final PracticeMode mode;

  /// ○×・空欄補充・説明から用語を出題に含めるか（既定は [kNewQuestionTypesEnabled]）。
  /// false のときは [questions] に含まれていても出さない（二重の防御）。
  final bool newTypesEnabled;

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

  late final List<Question> _pool =
      selectableQuestions(widget.questions, newTypesEnabled: widget.newTypesEnabled);

  PracticeSession _newSession() {
    final size = widget.priorityQids.isEmpty
        ? widget.sessionSize.clamp(1, _pool.length)
        : widget.priorityQids.length.clamp(1, _pool.length);
    return PracticeSession(
      pool: _pool,
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
    _recordResult(q, correct: i == q.answerIndex);
  }

  /// 新タイプ（○×・空欄補充・説明から用語）の解答。core の画面の結果を
  /// [PracticeSession] に渡し、履歴・進捗・復習予定にも記録する。
  void _answerNewType(Question q, QuestionViewResult r) {
    if (_answered || _displayQuestion?.qid != q.qid) return;
    setState(() => _answered = true);
    switch (q.type) {
      case QuestionType.trueFalse:
        _session.answerTrueFalse(r.boolAnswer!);
      case QuestionType.cloze:
        _session.answerCloze(r.blankAnswers!);
      case QuestionType.reverseLookup:
        _session.answerReverseLookup(r.text!);
      case QuestionType.choice:
      case QuestionType.journal:
      case QuestionType.worksheet:
      case QuestionType.ledger:
        return;
    }
    _recordResult(q, correct: r.correct);
  }

  /// 自由入力の打ち間違いを本人が「合っていた」と申告したとき。直前の不正解の記録を正解に直す。
  void _selfReported(Question q) {
    _session.markLastSelfReportedCorrect();
    ref.read(historyProvider.notifier).markLatestCorrect(q.qid);
    ref.read(srsProvider.notifier).recordAnswer(qid: q.qid, correct: true);
    recordReviewResult(q.qid, correct: true, at: DateTime.now());
  }

  void _recordResult(Question q, {required bool correct}) {
    ref.read(srsProvider.notifier).recordAnswer(qid: q.qid, correct: correct);
    recordDailyAnswer(ref);
    final at = DateTime.now();
    ref.read(historyProvider.notifier).record(
          q,
          correct: correct,
          ms: at.difference(_shownAt).inMilliseconds,
          at: at,
        );
    // 今日の復習の対象なら、結果を復習日程に反映する(履歴と同じ時刻)。
    recordReviewResult(q.qid, correct: correct, at: at);
    grantAnswerCoins(ref, q.qid, ref.read(historyProvider));
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
    if (_pool.isEmpty) {
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

    // ハンズフリー表示は選択式前提。新タイプは通常の画面（core の画面）で出す。
    if (ref.watch(handsFreeProvider).enabled && !_answered && !isNewQuestionType(q)) {
      return HandsFreeChoiceBody(
        qid: q.qid,
        prompt: q.prompt,
        choices: q.choices,
        index: _session.questions.indexOf(q) + 1,
        total: _session.questions.length,
        onSelect: _select,
      );
    }

    if (isNewQuestionType(q)) return _buildNewType(q);

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

  /// 新タイプの問題。出題・採点・解説・間違えた理由・「次へ」は core の画面が受け持つ。
  Widget _buildNewType(Question q) {
    final index = _session.questions.indexOf(q) + 1;
    final total = _session.questions.length;
    void onCause(WrongCause? c) => ref.read(historyProvider.notifier).setCause(q.qid, c);
    final Widget view = switch (q.type) {
      QuestionType.trueFalse => TrueFalseQuestionView(
          key: ValueKey('tf-${q.qid}'),
          question: q,
          terms: const [],
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onCause: onCause,
          onNext: _next,
        ),
      QuestionType.cloze => ClozeQuestionView(
          key: ValueKey('cloze-${q.qid}'),
          question: q,
          terms: const [],
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onSelfReported: () => _selfReported(q),
          onCause: onCause,
          onNext: _next,
        ),
      QuestionType.reverseLookup => ReverseLookupQuestionView(
          key: ValueKey('rev-${q.qid}'),
          question: q,
          terms: const [],
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onSelfReported: () => _selfReported(q),
          onCause: onCause,
          onNext: _next,
        ),
      QuestionType.choice ||
      QuestionType.journal ||
      QuestionType.worksheet ||
      QuestionType.ledger =>
        const SizedBox.shrink(),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: BookmarkToggleButton(qid: q.qid),
          ),
          view,
          if (_answered) ...[
            const SizedBox(height: 12),
            QuestionMemoField(key: ValueKey(q.qid), qid: q.qid),
          ],
        ],
      ),
    );
  }
}
