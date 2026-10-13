import 'package:app_common_kit/app_common_kit.dart'
    show FakeEntitlementService, InMemoryHandsFreeStore, entitlementServiceProvider, handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart' show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart' show studyNotesOverrides;
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('バージョンは固定文字でなく、実際の版を表示する', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'com.example.test',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
          handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
          ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
          ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
          ...(await tester.runAsync(() => reminderOverrides('test')))!,
          ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
          dailyGoalAchievementsOverride,
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('バージョン'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('9.8.7'), findsOneWidget);
    expect(find.text('0.1.0'), findsNothing);
  });
}
