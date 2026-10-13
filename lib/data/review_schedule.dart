import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'core_features.dart';

/// 「今日の復習」(間違いノートの復習日程。端末内)。
/// 保存するのは問題ID・段・次回の日・分野IDだけ。間違いノート([mistakeNoteStore])から
/// いつでも作り直せる派生データなので、バックアップ対象にはしない。
final ReviewSchedulerStore reviewSchedulerStore =
    SharedPreferencesReviewSchedulerStore(kExamId);

const ReviewSchedulerEngine reviewSchedulerEngine = ReviewSchedulerEngine();

/// 1問の解答結果を復習日程に反映する。呼ぶのは解答を履歴に記録した箇所(時刻は履歴と同じ [at])。
///
/// 今日の期限が来ている問題だけを進める(期限前に通常の演習で解いた分で段が進まないように)。
/// 復習日程に無い問題・期限前の問題は何もしない。間違えた場合の「やり直し」は
/// 間違いノートからの同期([ReviewSchedulerEngine.sync])が行う。保存に失敗しても学習は止めない。
Future<void> recordReviewResult(
  String qid, {
  required bool correct,
  required DateTime at,
  ReviewSchedulerStore? store,
}) async {
  try {
    final s = store ?? reviewSchedulerStore;
    final items = await s.read();
    final target = items.where((i) => i.qid == qid).toList();
    if (target.isEmpty || !reviewSchedulerEngine.isDue(target.first, at)) {
      return;
    }
    await s.write(
      reviewSchedulerEngine.applyResult(items, qid, correct: correct, now: at),
    );
  } catch (_) {
    // 復習日程は派生データ。次回の同期で整う。
  }
}
