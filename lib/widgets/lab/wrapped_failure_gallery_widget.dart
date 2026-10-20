import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show FailureChoiceSpec, LabStrings, LearningCurvePointSpec;

import 'wrapped_choice_chip.dart';

/// ukalab_core の `FailureGalleryWidget` の、選択肢と凡例を折り返して全文表示する版。
/// 学習の失敗図鑑（型⑦、決定76）。
///
/// 体験: 学習曲線（訓練・検証誤差のグラフ）を見て [symptomOptions] から症状
/// （過学習・未学習など）を当てる→正解すると [treatmentOptions] から処方
/// （対策）を選ぶ→[explanation] を見る。コード描画のみ（AI呼び出しなし）。
class WrappedFailureGalleryWidget extends StatefulWidget {
  const WrappedFailureGalleryWidget({
    super.key,
    required this.title,
    required this.curve,
    required this.symptomOptions,
    required this.treatmentOptions,
    required this.explanation,
  });

  final String title;
  final List<LearningCurvePointSpec> curve;
  final List<FailureChoiceSpec> symptomOptions;
  final List<FailureChoiceSpec> treatmentOptions;
  final String explanation;

  @override
  State<WrappedFailureGalleryWidget> createState() => _WrappedFailureGalleryWidgetState();
}

enum _FailureStep { symptom, treatment, done }

class _WrappedFailureGalleryWidgetState extends State<WrappedFailureGalleryWidget> {
  _FailureStep _step = _FailureStep.symptom;
  String? _wrongSymptomId;
  String? _wrongTreatmentId;

  void _selectSymptom(FailureChoiceSpec o) {
    setState(() {
      if (o.isCorrect) {
        _step = _FailureStep.treatment;
        _wrongSymptomId = null;
      } else {
        _wrongSymptomId = o.optionId;
      }
    });
  }

  void _selectTreatment(FailureChoiceSpec o) {
    setState(() {
      if (o.isCorrect) {
        _step = _FailureStep.done;
        _wrongTreatmentId = null;
      } else {
        _wrongTreatmentId = o.optionId;
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
        AspectRatio(
          aspectRatio: 16 / 9,
          child: CustomPaint(
            painter: _LearningCurvePainter(curve: widget.curve, theme: theme),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendDot(color: theme.colorScheme.primary, label: LabStrings.of(context).trainError),
            _LegendDot(color: theme.colorScheme.error, label: LabStrings.of(context).validationError),
          ],
        ),
        const SizedBox(height: 12),
        switch (_step) {
          _FailureStep.symptom => _ChoiceStep(
              prompt: LabStrings.of(context).symptomPrompt,
              options: widget.symptomOptions,
              wrongOptionId: _wrongSymptomId,
              onSelect: _selectSymptom,
            ),
          _FailureStep.treatment => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LabStrings.of(context).symptomIs(widget.symptomOptions.firstWhere((o) => o.isCorrect).text),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 8),
                _ChoiceStep(
                  prompt: LabStrings.of(context).treatmentPrompt,
                  options: widget.treatmentOptions,
                  wrongOptionId: _wrongTreatmentId,
                  onSelect: _selectTreatment,
                ),
              ],
            ),
          _FailureStep.done => Card(
              margin: EdgeInsets.zero,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LabStrings.of(context).gotIt,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.explanation, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
        },
      ],
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.prompt,
    required this.options,
    required this.wrongOptionId,
    required this.onSelect,
  });

  final String prompt;
  final List<FailureChoiceSpec> options;
  final String? wrongOptionId;
  final void Function(FailureChoiceSpec) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              WrappedChoiceChip(
                text: o.text,
                selected: o.optionId == wrongOptionId,
                onSelected: (_) => onSelect(o),
              ),
          ],
        ),
        if (wrongOptionId != null) ...[
          const SizedBox(height: 8),
          Text(
            LabStrings.of(context).wrongTryAgain,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

class _LearningCurvePainter extends CustomPainter {
  const _LearningCurvePainter({required this.curve, required this.theme});

  final List<LearningCurvePointSpec> curve;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) return;

    final minEpoch = curve.map((p) => p.epoch).reduce(math.min).toDouble();
    final maxEpoch = curve.map((p) => p.epoch).reduce(math.max).toDouble();
    final maxLoss = curve
        .expand((p) => [p.trainLoss, p.valLoss])
        .fold(0.0, math.max);

    final axisPaint = Paint()
      ..color = theme.colorScheme.outlineVariant
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);

    double dx(int epoch) => maxEpoch == minEpoch
        ? size.width / 2
        : (epoch - minEpoch) / (maxEpoch - minEpoch) * size.width;
    double dy(double loss) =>
        maxLoss <= 0 ? size.height : size.height - (loss / maxLoss) * size.height;

    void drawSeries(double Function(LearningCurvePointSpec) lossOf, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < curve.length; i++) {
        final p = Offset(dx(curve[i].epoch), dy(lossOf(curve[i])));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    drawSeries((p) => p.trainLoss, theme.colorScheme.primary);
    drawSeries((p) => p.valLoss, theme.colorScheme.error);
  }

  @override
  bool shouldRepaint(covariant _LearningCurvePainter oldDelegate) =>
      oldDelegate.curve != curve || oldDelegate.theme != theme;
}
