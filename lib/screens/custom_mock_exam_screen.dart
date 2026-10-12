import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// カスタム模擬試験の設定（プレミアム機能）。
class CustomMockExamSetup {
  const CustomMockExamSetup({required this.subjectIds, required this.count});

  final List<String> subjectIds;
  final int count;
}

/// 科目・問題数を選ぶ画面。選択結果を [CustomMockExamSetup] として返す。
class CustomMockExamSetupScreen extends StatefulWidget {
  const CustomMockExamSetupScreen({super.key, required this.subjects});

  final List<SubjectConfig> subjects;

  @override
  State<CustomMockExamSetupScreen> createState() => _CustomMockExamSetupScreenState();
}

class _CustomMockExamSetupScreenState extends State<CustomMockExamSetupScreen> {
  final Set<String> _selected = {};
  int _count = 20;

  static const _countOptions = [10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    final subjects = [...widget.subjects]..sort((a, b) => a.order.compareTo(b.order));
    return Scaffold(
      appBar: AppBar(title: const Text('カスタム模擬試験')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('出題する章', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  FilterChip(
                    label: Text(s.name),
                    selected: _selected.contains(s.subjectId),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(s.subjectId);
                      } else {
                        _selected.remove(s.subjectId);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('問題数', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _countOptions)
                  ChoiceChip(
                    label: Text('$c問'),
                    selected: _count == c,
                    onSelected: (_) => setState(() => _count = c),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        CustomMockExamSetup(subjectIds: _selected.toList(), count: _count),
                      ),
              child: const Text('この条件で始める'),
            ),
          ],
        ),
      ),
    );
  }
}
