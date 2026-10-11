import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'history_store.dart';
import 'srs_repository.dart';

/// 設定タブの「データの管理」（書き出し・読み込み・リセット）の対象。
///
/// 解答履歴・間隔反復の記録・自分用メモが対象。試験日・ブックマークは
/// ユーザー設定・curationとして扱い、含めない。
final List<DataPart> seiseiDataParts = [
  DataPart(
    id: 'history',
    export: (ref) => encodeHistory(ref.read(historyProvider)),
    restore: (ref, json) => ref.read(historyProvider.notifier).replace(decodeHistory(json as String?)),
    reset: (ref) => ref.read(historyProvider.notifier).reset(),
  ),
  DataPart(
    id: 'srs',
    export: (ref) {
      final store = ref.read(srsProvider).valueOrNull ?? const SrsStore({}, {});
      return {
        'items': [for (final i in store.items.values) i.toJson()],
        'stats': [for (final s in store.stats.values) s.toJson()],
      };
    },
    restore: (ref, json) {
      final map = json as Map<String, dynamic>;
      final items = [for (final e in (map['items'] as List).cast<Map<String, dynamic>>()) SrsItem.fromJson(e)];
      final stats = [for (final e in (map['stats'] as List).cast<Map<String, dynamic>>()) AnswerStat.fromJson(e)];
      return ref.read(srsProvider.notifier).replace(SrsStore(
            {for (final i in items) i.qid: i},
            {for (final s in stats) s.qid: s},
          ));
    },
    reset: (ref) => ref.read(srsProvider.notifier).reset(),
  ),
  DataPart(
    id: 'dailyGoal',
    export: (ref) => ref.read(dailyGoalProvider).toJson(),
    restore: (ref, json) =>
        ref.read(dailyGoalProvider.notifier).restore(DailyGoal.fromJson(json as Map<String, dynamic>)),
    reset: (ref) => ref.read(dailyGoalProvider.notifier).reset(),
  ),
  DataPart(
    id: 'dailyGoalHistory',
    export: (ref) => [for (final e in ref.read(dailyGoalHistoryProvider)) e.toJson()],
    restore: (ref, json) => ref.read(dailyGoalHistoryProvider.notifier).restore([
      for (final j in (json as List).cast<Map<String, dynamic>>()) DailyGoalHistoryEntry.fromJson(j),
    ]),
    reset: (ref) => ref.read(dailyGoalHistoryProvider.notifier).reset(),
  ),
  DataPart(
    id: 'questionMemo',
    export: (ref) => ref.read(questionMemoProvider),
    restore: (ref, json) =>
        ref.read(questionMemoProvider.notifier).restore((json as Map<String, dynamic>).cast<String, String>()),
    reset: (ref) => ref.read(questionMemoProvider.notifier).reset(),
  ),
];
