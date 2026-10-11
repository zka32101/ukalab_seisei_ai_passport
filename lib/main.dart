import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukalab_core/exam_date.dart';
import 'data/exam_repository.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/mock_exam_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 課金（RevenueCat）。実際のAPIキー取得後にRevenueCatEntitlementServiceへ差し替える。
  // 価格は競合調査を踏まえた暫定値で、運営者確認が必要（決定14）。
  final entitlementService = FakeEntitlementService(
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

  final studyNotes = await studyNotesOverrides('seisei_ai_passport');
  final dailyGoal = await dailyGoalOverrides('seisei_ai_passport');
  final container = ProviderContainer(
    overrides: [
      ...studyNotes,
      ...dailyGoal,
      entitlementServiceProvider.overrideWithValue(entitlementService),
      handsFreeStoreProvider.overrideWithValue(SharedPreferencesHandsFreeStore('seisei_ai_passport')),
      examDateStoreProvider.overrideWithValue(ExamDateStore('seisei_ai_passport')),
    ],
  );
  await container.read(handsFreeProvider.notifier).load();
  await container.read(examDateProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UkalabSeiseiAiPassportApp(),
    ),
  );
}

class UkalabSeiseiAiPassportApp extends StatelessWidget {
  const UkalabSeiseiAiPassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            LearnScreen(questions: questions),
            MockExamScreen(exam: data.exam, questions: questions),
            const RecordScreen(),
            SettingsScreen(questions: questions),
          ],
        );
      },
    );
  }
}
