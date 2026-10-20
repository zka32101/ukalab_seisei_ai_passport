import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show LabStrings, MisconceptionChoiceSpec;

import 'wrapped_choice_chip.dart';

/// ukalab_core の `TeachMascotWidget` の、選択肢を折り返して全文表示する版。
/// 推しが「よくある誤り」を含む答案を出し、誤りをタップして正しい部品に
/// 差し替えると推しが理解する演出（決定76）。
///
/// 推しの成長（Lv）はこの演出とは独立しており、既存の習得度計算のみに
/// 基づく。答案添削はあくまで演出で、ゲーム的な成長要素ではない（決定77）。
///
/// [statementTemplate] は `{blank}` を1つ含む文。最初は [options] の誤った
/// 選択肢の1つが空欄に入った状態で表示する。
class WrappedTeachMascotWidget extends StatefulWidget {
  const WrappedTeachMascotWidget({
    super.key,
    required this.title,
    required this.statementTemplate,
    required this.options,
    required this.explanation,
  });

  final String title;
  final String statementTemplate;
  final List<MisconceptionChoiceSpec> options;
  final String explanation;

  @override
  State<WrappedTeachMascotWidget> createState() => _WrappedTeachMascotWidgetState();
}

class _WrappedTeachMascotWidgetState extends State<WrappedTeachMascotWidget> {
  late String _selectedOptionId;
  bool _solved = false;
  bool _justWrong = false;

  @override
  void initState() {
    super.initState();
    final firstWrong = widget.options.firstWhere(
      (o) => !o.isCorrect,
      orElse: () => widget.options.first,
    );
    _selectedOptionId = firstWrong.optionId;
  }

  MisconceptionChoiceSpec get _selected =>
      widget.options.firstWhere((o) => o.optionId == _selectedOptionId);

  void _select(MisconceptionChoiceSpec option) {
    setState(() {
      _selectedOptionId = option.optionId;
      if (option.isCorrect) {
        _solved = true;
        _justWrong = false;
      } else {
        _justWrong = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _solved ? LabStrings.of(context).gotIt : LabStrings.of(context).mascotStuck,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: () {
                    final parts = widget.statementTemplate.split('{blank}');
                    return [
                      TextSpan(text: parts.first),
                      TextSpan(
                        text: _selected.text,
                        style: TextStyle(
                          color: _solved ? theme.colorScheme.primary : theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                          decoration: _solved ? null : TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: parts.length > 1 ? parts.sublist(1).join('{blank}') : ''),
                    ];
                  }()),
                  style: theme.textTheme.bodyLarge,
                ),
                if (_justWrong && !_solved) ...[
                  const SizedBox(height: 8),
                  Text(
                    LabStrings.of(context).wrongTryAgain,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in widget.options)
              WrappedChoiceChip(
                text: o.text,
                selected: o.optionId == _selectedOptionId,
                onSelected: _solved ? null : (_) => _select(o),
              ),
          ],
        ),
        if (_solved) ...[
          const SizedBox(height: 12),
          Text(widget.explanation, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
