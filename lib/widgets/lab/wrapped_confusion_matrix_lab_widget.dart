import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show ConfusionMatrixScenarioSpec, FailureChoiceSpec, LabStrings;

import 'wrapped_choice_chip.dart';

/// ukalab_core の `ConfusionMatrixLabWidget` の、選択肢を折り返して全文表示する版。
/// 評価指標ラボ（画期的な機能3）。
///
/// 体験: 混同行列（TP/FP/FN/TN）をスライダーで自由に動かし、正解率・適合率・
/// 再現率・F値が連動する様子を見る→[ConfusionMatrixScenarioSpec.description]
/// の場面で「偽陽性と偽陰性のどちらが重いか」を[ConfusionMatrixScenarioSpec.options]
/// から選ぶ→正解すると[ConfusionMatrixScenarioSpec.explanation]を見る。
/// コード描画のみ（AI呼び出しなし）。
class WrappedConfusionMatrixLabWidget extends StatefulWidget {
  const WrappedConfusionMatrixLabWidget({super.key, required this.scenario});

  final ConfusionMatrixScenarioSpec scenario;

  @override
  State<WrappedConfusionMatrixLabWidget> createState() => _WrappedConfusionMatrixLabWidgetState();
}

class _WrappedConfusionMatrixLabWidgetState extends State<WrappedConfusionMatrixLabWidget> {
  late int _tp;
  late int _fp;
  late int _fn;
  late int _tn;
  String? _wrongOptionId;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tp = widget.scenario.initialTp;
    _fp = widget.scenario.initialFp;
    _fn = widget.scenario.initialFn;
    _tn = widget.scenario.initialTn;
  }

  int get _maxCell => math.max(100, _tp + _fp + _fn + _tn);

  double get _accuracy {
    final total = _tp + _fp + _fn + _tn;
    return total <= 0 ? 0 : (_tp + _tn) / total;
  }

  double get _precision {
    final denom = _tp + _fp;
    return denom <= 0 ? 0 : _tp / denom;
  }

  double get _recall {
    final denom = _tp + _fn;
    return denom <= 0 ? 0 : _tp / denom;
  }

  double get _f1 {
    final p = _precision;
    final r = _recall;
    final denom = p + r;
    return denom <= 0 ? 0 : 2 * p * r / denom;
  }

  void _select(FailureChoiceSpec o) {
    setState(() {
      if (o.isCorrect) {
        _done = true;
        _wrongOptionId = null;
      } else {
        _wrongOptionId = o.optionId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.scenario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _CellSlider(label: LabStrings.of(context).cmTp, value: _tp, max: _maxCell, onChanged: (v) => setState(() => _tp = v)),
        _CellSlider(label: LabStrings.of(context).cmFp, value: _fp, max: _maxCell, onChanged: (v) => setState(() => _fp = v)),
        _CellSlider(label: LabStrings.of(context).cmFn, value: _fn, max: _maxCell, onChanged: (v) => setState(() => _fn = v)),
        _CellSlider(label: LabStrings.of(context).cmTn, value: _tn, max: _maxCell, onChanged: (v) => setState(() => _tn = v)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _StatChip(label: LabStrings.of(context).cmAccuracy, value: _accuracy),
            _StatChip(label: LabStrings.of(context).cmPrecision, value: _precision),
            _StatChip(label: LabStrings.of(context).cmRecall, value: _recall),
            _StatChip(label: LabStrings.of(context).cmF1, value: _f1),
          ],
        ),
        const SizedBox(height: 16),
        Text(s.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        if (!_done) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in s.options)
                WrappedChoiceChip(
                  text: o.text,
                  selected: o.optionId == _wrongOptionId,
                  onSelected: (_) => _select(o),
                ),
            ],
          ),
          if (_wrongOptionId != null) ...[
            const SizedBox(height: 8),
            Text(
              LabStrings.of(context).wrongTryAgain,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ] else
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LabStrings.of(context).gotIt,
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(s.explanation, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CellSlider extends StatelessWidget {
  const _CellSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: max.toDouble(),
            divisions: max,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        // 数値の欄は文字倍率に合わせて広げる（固定幅だと桁が縦に折れる）
        SizedBox(width: MediaQuery.textScalerOf(context).scale(32), child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(
        '$label ${(value * 100).toStringAsFixed(1)}%',
        style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
      ),
      backgroundColor: theme.colorScheme.secondaryContainer,
    );
  }
}
