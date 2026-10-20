import 'package:flutter/material.dart';

/// 選択肢の文章を折り返して全文を見せる ChoiceChip。
///
/// 標準の `ChoiceChip` はラベルを 1 行に固定して端を薄く消してしまうため、狭い幅や大きい文字で
/// 選択肢の後半が読めなくなる。ここではラベルに専用の DefaultTextStyle を入れ、折り返しを許す。
/// ukalab_core の体験ラボ部品(v0.78.0)が標準 ChoiceChip を使っている間の、このアプリ側の差し替え。
class WrappedChoiceChip extends StatelessWidget {
  const WrappedChoiceChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onSelected,
  });

  final String text;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Wrap の中でも画面幅を超えない(超えると折り返し先が無く切れる)。
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
      child: ChoiceChip(
        // チップが渡した文字スタイル(選択中の色など)は引き継ぎ、折り返しだけ許す。
        label: Builder(
          builder: (context) => DefaultTextStyle(
            style: DefaultTextStyle.of(context).style,
            softWrap: true,
            overflow: TextOverflow.visible,
            child: Text(text),
          ),
        ),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
