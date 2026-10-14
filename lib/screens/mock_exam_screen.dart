import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/srs_repository.dart';

/// 「模擬」タブ: 本試験相当の採点（合格ラインの目安は非公開のため70%を目安と明記）。
/// 出題は、記録タブの解答実績から苦手な科目（正答率が低い科目）を優先的に多く含める。
class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key, required this.exam, required this.questions});

  final ExamConfig exam;
  final List<Question> questions;

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  bool _started = false;
  int _index = 0;
  final Map<String, int?> _answers = {};
  late List<Question> _picked;
  MockExamResult? _result;

  bool _isPremium(WidgetRef ref) => canUsePremiumFeature(
        PremiumFeature.mockExamHistory,
        isPremium: (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free)
            .hasPremium,
      );

  void _start() {
    final level = widget.exam.levels.first;
    final count = level.questionCount.clamp(1, widget.questions.length);
    final store = ref.read(srsProvider).valueOrNull ?? const SrsStore({}, {});
    setState(() {
      _picked = _pickWeighted(widget.questions, count, store);
      _answers.clear();
      _index = 0;
      _started = true;
      _result = null;
    });
  }

  void _startCustom(List<String> subjectIds, int count) {
    setState(() {
      _picked = pickCustomMockExamQuestions(
        pool: widget.questions,
        subjectIds: subjectIds,
        count: count,
        seed: DateTime.now().millisecondsSinceEpoch,
      )..shuffle();
      _answers.clear();
      _index = 0;
      _started = true;
      _result = null;
    });
  }

  Future<void> _openCustomSetup() async {
    final setup = await Navigator.of(context).push<CustomMockExamSetup>(
      MaterialPageRoute(
        builder: (_) => CustomMockExamSetupScreen(subjects: widget.exam.subjects),
      ),
    );
    if (setup != null) _startCustom(setup.subjectIds, setup.count);
  }

  void _select(int i) {
    setState(() => _answers[_picked[_index].qid] = i);
  }

  Future<void> _finish() async {
    final rule = widget.exam.levels.first.passRule;
    final result = scoreMockExam(questions: _picked, answers: _answers, rule: rule);
    setState(() => _result = result);
    if (_isPremium(ref)) {
      await ref.read(mockExamHistoryProvider.notifier).record(result);
    }
  }

  void _next() {
    if (_index + 1 < _picked.length) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const EmptyState(message: '問題データがまだありません。');
    }
    final level = widget.exam.levels.first;

    if (!_started) {
      // 大きい文字・狭い幅でも下が切れないよう、縦にスクロールできるようにする。
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('模擬試験', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '本試験は${level.questionCount}問・${(level.timeLimitSec ?? 0) ~/ 60}分。'
                '合格基準は非公開のため、正答率70%を目安に表示します。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _start, child: const Text('模擬試験を始める')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  if (!_isPremium(ref)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('カスタム模擬試験はプレミアムの機能です。設定から購入できます。')),
                    );
                    return;
                  }
                  _openCustomSetup();
                },
                child: const Text('カスタム模擬試験'),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result != null) {
      final history = _isPremium(ref) ? ref.watch(mockExamHistoryProvider) : const <MockExamHistoryEntry>[];
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResultSummary(
                correct: result.total.score,
                total: result.total.max,
                passRatio: 0.70,
                onRetry: _start,
              ),
              const SizedBox(height: 16),
              // この模擬試験の分野別の様子(科目ごと)。点数では責めず、次に少しだけやる分野を出す。
              MockExamAnalysisCard(
                analysis: const MockExamAnalysisEngine().analyze([
                  for (final q in _picked)
                    if (_answers[q.qid] != null)
                      MockExamAnswer(
                        topicId: q.subjectId,
                        correct: _answers[q.qid] == q.answerIndex,
                      ),
                ]),
                topicLabel: (id) => widget.exam.subject(id)?.name ?? id,
              ),
              if (history.length > 1) ...[
                const SizedBox(height: 16),
                Text('成長グラフ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                MockExamTrendChart(
                  points: [
                    for (final h in history) MockExamTrendPoint(pct: h.pct, passed: h.passed),
                  ],
                  passPct: 70,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final q = _picked[_index];
    final selected = _answers[q.qid];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionCard(
            text: q.prompt,
            index: _index + 1,
            total: _picked.length,
            child: Column(
              children: [
                for (var i = 0; i < q.choices.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  ChoiceTile(
                    label: String.fromCharCode(0x41 + i),
                    text: q.choices[i],
                    state: selected == i ? ChoiceState.selected : ChoiceState.idle,
                    onTap: () => _select(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null ? null : _next,
            child: Text(_index + 1 < _picked.length ? '次へ' : '結果を見る'),
          ),
        ],
      ),
    );
  }
}

/// [count]問を[pool]から選ぶ。科目ごとの正答率が低いほど出題されやすくする
/// （未解答の科目は標準の重み）。解答実績が無ければ一様ランダムと同じになる。
List<Question> _pickWeighted(List<Question> pool, int count, SrsStore store) {
  final statsBySubject = store.statsBySubject(pool);

  double weightFor(String subjectId) {
    final stat = statsBySubject[subjectId];
    if (stat == null) return 1.0;
    final accuracy = stat.$1 / stat.$2;
    return (1.0 - accuracy) + 0.3;
  }

  final weighted = <Question>[];
  for (final q in pool) {
    final reps = (weightFor(q.subjectId) * 10).round().clamp(1, 20);
    weighted.addAll(List.filled(reps, q));
  }
  weighted.shuffle(Random());

  final picked = <Question>[];
  final seenQids = <String>{};
  for (final q in weighted) {
    if (picked.length >= count) break;
    if (seenQids.add(q.qid)) picked.add(q);
  }
  return picked;
}
