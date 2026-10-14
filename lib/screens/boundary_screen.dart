import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/boundary_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「境界線スライダー」体験（型①、決定76・77）。条件を1つずつ切り替え、
/// 判定が切り替わる境目を体験する。判定は参考用の「目安」で法的助言ではない。
class BoundaryScreen extends ConsumerStatefulWidget {
  const BoundaryScreen({super.key});

  @override
  ConsumerState<BoundaryScreen> createState() => _BoundaryScreenState();
}

class _BoundaryScreenState extends ConsumerState<BoundaryScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(boundaryScenariosProvider);
    return Scaffold(
      appBar: wrappedAppBar(context, '境界線スライダー'),
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
                BoundarySliderWidget(
                  key: ValueKey(s.scenarioId),
                  title: s.title,
                  conditions: [
                    for (final c in s.conditions)
                      BoundaryConditionSpec(
                        conditionId: c.conditionId,
                        label: c.label,
                        trueLabel: c.trueLabel,
                        falseLabel: c.falseLabel,
                      ),
                  ],
                  evaluate: (values) {
                    final rule = s.evaluate(values);
                    if (rule == null) return null;
                    return BoundaryConclusion(
                      text: rule.conclusion,
                      lawReference: rule.lawReference,
                    );
                  },
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
