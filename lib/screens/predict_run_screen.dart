import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/predict_run_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「温度の実験室」（予測→実行、型②、決定76）。先に答えを予測してから、
/// 計算結果とのズレを見て学ぶ。
class PredictRunScreen extends ConsumerStatefulWidget {
  const PredictRunScreen({super.key});

  @override
  ConsumerState<PredictRunScreen> createState() => _PredictRunScreenState();
}

class _PredictRunScreenState extends ConsumerState<PredictRunScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(predictRunScenariosProvider);
    return Scaffold(
      appBar: wrappedAppBar(context, '温度の実験室'),
      body: scenarios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('読み込みに失敗しました。\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(message: 'まだ場面がありません。');
          }
          if (_index >= list.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全${list.length}場面、お疲れさまでした！',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _index = 0),
                      child: const Text('もう一度'),
                    ),
                  ],
                ),
              ),
            );
          }

          final s = list[_index];
          final isExpectedValue = s.kind == PredictRunKind.expectedValue;
          final maxValue = isExpectedValue
              ? s.outcomes.map((o) => o.value).reduce((a, b) => a > b ? a : b) * 1.2
              : 1.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_index + 1} / ${list.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                PredictRunWidget(
                  key: ValueKey(s.scenarioId),
                  title: s.title,
                  question: s.question,
                  correctAnswer: s.compute(),
                  explanation: s.explanation,
                  min: 0,
                  max: maxValue,
                  valueLabel:
                      isExpectedValue ? (v) => '${v.round()}円' : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _index++),
                  child: Text(_index + 1 < list.length ? '次へ' : '結果を見る'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
