import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/misconception_repository.dart';
import '../widgets/lab/wrapped_teach_mascot_widget.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「推しの答案を添削」体験（型③、決定76・77）。推しがよくある誤りを含む
/// 答案を出し、正しい選択肢に差し替えると理解する演出。推しの成長（Lv）とは
/// 独立した演出であり、ゲーム的な成長要素ではない。
class TeachMascotScreen extends ConsumerStatefulWidget {
  const TeachMascotScreen({super.key});

  @override
  ConsumerState<TeachMascotScreen> createState() => _TeachMascotScreenState();
}

class _TeachMascotScreenState extends ConsumerState<TeachMascotScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(misconceptionScenariosProvider);
    return Scaffold(
      appBar: wrappedAppBar(context, '推しの答案を添削'),
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
                WrappedTeachMascotWidget(
                  key: ValueKey(s.scenarioId),
                  title: s.title,
                  statementTemplate: s.statementTemplate,
                  options: [
                    for (final o in s.options)
                      MisconceptionChoiceSpec(
                        optionId: o.optionId,
                        text: o.text,
                        isCorrect: o.isCorrect,
                      ),
                  ],
                  explanation: s.explanation,
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
