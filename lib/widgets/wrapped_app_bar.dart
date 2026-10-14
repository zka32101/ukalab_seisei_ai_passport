import 'package:flutter/material.dart';

/// 長い題名や大きい文字でも題名が「…」で切れない AppBar。
///
/// 既定の AppBar は題名を 1 行に固定して末尾を省略する。ここでは題名を折り返し、
/// 必要な行数に合わせて AppBar の高さを伸ばす(1 行で収まるときは既定の高さのまま)。
/// 試験名・章名・分野名のように、省略されると意味が変わる文言に使う。
PreferredSizeWidget wrappedAppBar(BuildContext context, String title) {
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle(fontSize: 22);
  final scaler = MediaQuery.textScalerOf(context);
  final screenWidth = MediaQuery.sizeOf(context).width;
  // 戻るボタン(56) と左右の余白ぶんを引いた、題名に使える幅。
  final available = (screenWidth - 56 - 16).clamp(80.0, double.infinity);
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: scaler,
  )..layout(maxWidth: available);
  final height = painter.height + 24;
  painter.dispose();
  return AppBar(
    toolbarHeight: height < kToolbarHeight ? kToolbarHeight : height,
    title: Text(title, softWrap: true, overflow: TextOverflow.visible),
  );
}
