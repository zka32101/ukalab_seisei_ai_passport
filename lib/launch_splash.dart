import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show UkalabStartupSplash;

/// アプリアイコン（アダプティブ背景）の紫。Android の起動画面
/// （res/values/colors.xml の launch_background）と同じ色にして、
/// 端末側の起動画面からアプリ内の読み込み画面まで見た目をつなぐ。
const Color kLaunchBackgroundColor = Color(0xFF9948C8);

/// アイコン前景（透過）。アプリ用に 256px へ縮小したもの。
const String kLaunchIconAsset = 'assets/branding/app_icon.png';

/// 問題データ読み込み中の画面。
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key});

  @override
  Widget build(BuildContext context) => const UkalabStartupSplash(
        iconAsset: kLaunchIconAsset,
        backgroundColor: kLaunchBackgroundColor,
        iconSize: 160,
      );
}
