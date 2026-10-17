import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/mock_exam_quota.dart';

import '../data/coin_grants.dart';
import '../data/feature_flags.dart';
import '../data/history_store.dart';
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

  /// 無料版は月の回数に上限がある。使える回数が残っていれば1回分を使って始める。
  Future<void> _tryStart() async {
    final quota = await mockExamQuota(isPremium: _isPremium(ref));
    if (!await quota.tryConsume()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('今月の模擬試験は使い切りました'),
          content: const Text(
            '無料版の模擬試験は、月に${1}回までです。来月になると、また受けられます。\n'
            'プレミアムなら、回数の制限なく受けられます（設定から購入できます）。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    _start();
  }

  void _start() {
    final level = widget.exam.levels.first;
    final count = level.questionCount.clamp(1, widget.questions.length);
    final store = ref.read(srsProvider).valueOrNull ?? const SrsStore({}, {});
    setState(() {
      _picked = _pickWeighted(mockExamEligible(widget.questions), count, store);
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
        allowedTypes: kMockExamAllowedTypes,
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
    grantCoin(ref, CoinEvent.mockDone());
    if (result.passed) {
      grantCoin(ref, CoinEvent.mockPass(widget.exam.examId));
      _markReadyIfMastered();
    }
    if (_isPremium(ref)) {
      await ref.read(mockExamHistoryProvider.notifier).record(result);
    }
  }

  /// 模擬に合格し、かつ習得度が十分なら「準備完了」の衣装を解放する（失敗しても止めない）。
  void _markReadyIfMastered() {
    try {
      final latest = <String, bool>{};
      for (final r in ref.read(historyProvider).reversed) {
        latest[r.qid] = r.correct;
      }
      final total = widget.questions.length;
      if (total == 0 || latest.isEmpty) return;
      final mastery = MasteryInput(
        coverage: (latest.length / total).clamp(0.0, 1.0),
        accuracy: latest.values.where((c) => c).length / latest.length,
      );
      if (ReadinessRule.standard.isReady(mastery: mastery, mockPassed: true)) {
        ref.read(outfitProvider.notifier).markReady(UkalabCert.genAiPassport).catchError((_) => false);
      }
    } catch (_) {}
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
              FilledButton(onPressed: _tryStart, child: const Text('模擬試験を始める')),
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
                onRetry: _tryStart,
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
