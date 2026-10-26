import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ui.dart' show UkalabStartupSplash;
import 'package:ukalab_seisei_ai_passport/launch_splash.dart';

void main() {
  testWidgets('LaunchSplash は UkalabStartupSplash にアイコンと背景色を渡す', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchSplash()));
    final splash = tester.widget<UkalabStartupSplash>(find.byType(UkalabStartupSplash));
    expect(splash.iconAsset, kLaunchIconAsset);
    expect(splash.backgroundColor, kLaunchBackgroundColor);
    expect(kLaunchBackgroundColor, const Color(0xFF9948C8));
  });
}
