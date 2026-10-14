import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/confusion_matrix_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「評価指標ラボ」体験（画期的な機能3）。混同行列（TP/FP/FN/TN）を動かして
/// 正解率・適合率・再現率・F値の連動を見たあと、偽陽性・偽陰性のどちらを
/// 重視すべきかを選ぶ。
class ConfusionMatrixScreen extends ConsumerStatefulWidget {
  const ConfusionMatrixScreen({super.key});

  @override
  ConsumerState<ConfusionMatrixScreen> createState() =>
      _ConfusionMatrixScreenState();
}

class _ConfusionMatrixScreenState
    extends ConsumerState<ConfusionMatrixScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(confusionMatrixScenariosProvider);
    return Scaffold(
      appBar: wrappedAppBar(context, '評価指標ラボ'),
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
                ConfusionMatrixLabWidget(
                  key: ValueKey(s.scenarioId),
                  scenario: ConfusionMatrixScenarioSpec(
                    title: s.title,
                    description: s.description,
                    initialTp: s.initialTp,
                    initialFp: s.initialFp,
                    initialFn: s.initialFn,
                    initialTn: s.initialTn,
                    options: [
                      for (final o in s.options)
                        FailureChoiceSpec(
                          optionId: o.optionId,
                          text: o.text,
                          isCorrect: o.isCorrect,
                        ),
                    ],
                    explanation: s.explanation,
                  ),
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
