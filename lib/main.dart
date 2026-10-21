import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:ukalab_core/achievements.dart'
    show achievementUnlockOverrides, dailyGoalAchievementsOverride, watchAchievementUnlocks;
import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromo;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'data/ad_unit_ids.dart';
import 'data/character_wiring.dart';
import 'data/coin_grants.dart';
import 'launch_splash.dart';
import 'data/exam_repository.dart';
import 'data/revenuecat_key.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/mock_exam_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/no_ads_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 相互紹介（Firebase 初期化 + Remote Config 取得）。失敗しても例外を投げず、起動も止めない。
  unawaited(UkalabCrossPromo.init());

  // 課金。RC_GOOGLE_KEY（Android）/ RC_APPLE_KEY（iOS）が渡されたビルドだけ RevenueCat を使い、
  // それ以外は仮の購入サービス。価格（仮サービス側）は競合調査を踏まえた暫定値で、運営者確認が必要（決定14）。
  // RevenueCat 側は entitlement ID を 'noads' / 'premium'、商品を現行オファリングに登録する。
  final rcKey = revenueCatKeyFor(
    isWeb: kIsWeb,
    isAndroid: !kIsWeb && Platform.isAndroid,
    isIOS: !kIsWeb && Platform.isIOS,
  );
  final EntitlementService entitlementService = rcKey != null
      ? await RevenueCatEntitlementService.init(publicSdkKey: rcKey)
      : FakeEntitlementService(
    availableOffers: const [
      EntitlementOffer(
        id: 'noads',
        productId: 'seisei_ai_passport_noads',
        title: '広告非表示',
        priceString: '¥480',
      ),
      EntitlementOffer(
        id: 'premium',
        productId: 'seisei_ai_passport_premium',
        title: 'プレミアム（広告非表示＋追加機能）',
        priceString: '¥1,500',
      ),
    ],
    grantOnPurchase: const {
      'seisei_ai_passport_noads': EntitlementState(hasNoAds: true),
      'seisei_ai_passport_premium': EntitlementState(hasPremium: true),
    },
  );

  // 広告。本番ユニットIDはビルド時に --dart-define で渡す（ad_unit_ids.dart）。
  // Web・iOS は広告を出さない。リリースで未指定なら空のIDで、広告なしのまま起動する。
  final adIds = adUnitIdsFor(
    isWeb: kIsWeb,
    isAndroid: !kIsWeb && Platform.isAndroid,
    isRelease: kReleaseMode,
  );
  final adGate = await AdGate.init(
    config: AdConfig(unitIds: adIds),
    // IDが空(Web・iOS、または本番IDが未指定のリリース)なら、広告SDKを使わず、広告なしで起動する。
    backend: adIds.banner.isEmpty && adIds.interstitial.isEmpty ? NoAdsBackend() : null,
    adsHidden: () => entitlementService.state.adsHidden,
    isRelease: kReleaseMode,
  );

  final studyNotes = await studyNotesOverrides('seisei_ai_passport');
  final dailyGoal = await dailyGoalOverrides('seisei_ai_passport');
  final reminder = await reminderOverrides('seisei_ai_passport');
  final achievementUnlock = await achievementUnlockOverrides('seisei_ai_passport');
  final mockExamHistory = await mockExamHistoryOverrides('seisei_ai_passport');
  final coinOutfit = await coinOutfitOverrides(kCoinAppKey);
  final container = ProviderContainer(
    overrides: [
      ...studyNotes,
      ...dailyGoal,
      ...reminder,
      ...achievementUnlock,
      ...mockExamHistory,
      ...coinOutfit,
      ...characterOverrides,
      dailyGoalAchievementsOverride,
      entitlementServiceProvider.overrideWithValue(entitlementService),
      adGateProvider.overrideWithValue(adGate),
      handsFreeStoreProvider.overrideWithValue(SharedPreferencesHandsFreeStore('seisei_ai_passport')),
      examDateStoreProvider.overrideWithValue(ExamDateStore('seisei_ai_passport')),
    ],
  );
  await container.read(handsFreeProvider.notifier).load();
  await container.read(examDateProvider.notifier).load();
  // 文字の大きさ（アプリ内設定）を復元する
  await loadSavedTextScale();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UkalabSeiseiAiPassportApp(),
    ),
  );
}

/// 実績の解除通知のスナックバーを、どの画面にいても表示するためのキー。
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class UkalabSeiseiAiPassportApp extends ConsumerWidget {
  const UkalabSeiseiAiPassportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAchievementUnlocks(ref, scaffoldMessengerKey);
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      // 文字の大きさ（設定画面で選ぶ）を端末の文字サイズに掛け合わせる。
      builder: applyAppTextScale,
      title: 'うかラボ 生成AIパスポート',
      debugShowCheckedModeBanner: false,
      theme: UkalabTheme.light(
        field: UkalabField.ai,
        cert: UkalabCert.genAiPassport,
      ),
      darkTheme: UkalabTheme.dark(
        field: UkalabField.ai,
        cert: UkalabCert.genAiPassport,
      ),
      home: const _RootPage(),
    );
  }
}

class _RootPage extends ConsumerWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examData = ref.watch(examDataProvider);
    return examData.when(
      loading: () => const LaunchSplash(),
      error: (e, st) => Scaffold(
        body: ErrorState(
          message: '問題データを読み込めませんでした。\n$e',
          onRetry: () => ref.invalidate(examDataProvider),
        ),
      ),
      data: (data) {
        final questions = data.activeQuestions;
        return UkalabShell(
          pages: [
            HomeScreen(exam: data.exam, questionCount: questions.length, questions: questions),
            LearnScreen(questions: questions, exam: data.exam),
            MockExamScreen(exam: data.exam, questions: questions),
            const RecordScreen(),
            SettingsScreen(questions: questions, exam: data.exam),
          ],
        );
      },
    );
  }
}
