import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart';
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_seisei_ai_passport/data/data_parts.dart';
import 'package:ukalab_seisei_ai_passport/data/srs_repository.dart';

void main() {
  test('パーツのidは重複しない', () {
    final ids = [for (final p in seiseiDataParts) p.id];
    expect(ids.toSet().length, ids.length);
    expect(ids, ['achievementUnlock', 'learnedTerms', 'history', 'srs', 'dailyGoal', 'dailyGoalHistory', 'questionMemo', 'examChecklist', 'mistakeNotes']);
  });

  testWidgets('間隔反復の記録を書き出し→リセット→読み込みで戻せる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late WidgetRef ref;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        achievementUnlockServiceProvider
            .overrideWithValue(AchievementUnlockService(store: AchievementUnlockStore('test'))),
        dailyGoalServiceProvider.overrideWithValue(DailyGoalService(store: DailyGoalStore('test'))),
        dailyGoalHistoryServiceProvider
            .overrideWithValue(DailyGoalHistoryService(store: DailyGoalHistoryStore('test'))),
        questionMemoServiceProvider
            .overrideWithValue(QuestionMemoService(store: SharedPreferencesQuestionMemoStore('test'))),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          }),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await ref.read(srsProvider.future);
      await ref.read(srsProvider.notifier).recordAnswer(qid: 'q1', correct: true);
      expect(ref.read(srsProvider).requireValue.items.keys, ['q1']);

      final text = await encodeLearningDataBackupAsync(ref, seiseiDataParts);

      await resetLearningData(ref, seiseiDataParts);
      expect(ref.read(srsProvider).requireValue.items, isEmpty);

      await restoreLearningDataBackup(ref, seiseiDataParts, text);
      final store = ref.read(srsProvider).requireValue;
      expect(store.items.keys, ['q1']);
      expect(store.stats['q1']!.attempts, 1);
    });
  });
}
