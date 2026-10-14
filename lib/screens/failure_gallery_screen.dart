import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/failure_gallery_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「学習の失敗図鑑」体験（型⑦、決定76）。学習曲線（訓練・検証誤差）を見て
/// 症状（過学習・未学習など）を当て、正解すると処方（対策）を選ぶ。
class FailureGalleryScreen extends ConsumerStatefulWidget {
  const FailureGalleryScreen({super.key});

  @override
  ConsumerState<FailureGalleryScreen> createState() =>
      _FailureGalleryScreenState();
}

class _FailureGalleryScreenState extends ConsumerState<FailureGalleryScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(failureCasesProvider);
    return Scaffold(
      appBar: wrappedAppBar(context, '学習の失敗図鑑'),
      body: cases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('読み込みに失敗しました。\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(message: 'まだ症例がありません。');
          }
          if (_index >= list.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全${list.length}症例、お疲れさまでした！',
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

          final c = list[_index];
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
                FailureGalleryWidget(
                  key: ValueKey(c.caseId),
                  title: '症例 ${_index + 1}',
                  curve: [
                    for (final p in c.curve)
                      LearningCurvePointSpec(
                        epoch: p.epoch,
                        trainLoss: p.trainLoss,
                        valLoss: p.valLoss,
                      ),
                  ],
                  symptomOptions: [
                    for (final o in c.symptomOptions)
                      FailureChoiceSpec(
                        optionId: o.optionId,
                        text: o.text,
                        isCorrect: o.isCorrect,
                      ),
                  ],
                  treatmentOptions: [
                    for (final o in c.treatmentOptions)
                      FailureChoiceSpec(
                        optionId: o.optionId,
                        text: o.text,
                        isCorrect: o.isCorrect,
                      ),
                  ],
                  explanation: c.explanation,
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
