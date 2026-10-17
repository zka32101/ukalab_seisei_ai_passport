import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/mock_exam_quota.dart';
import 'package:ukalab_seisei_ai_passport/data/review_schedule.dart';

class _MemoryReviewStore implements ReviewSchedulerStore {
  _MemoryReviewStore(this.items);
  List<ReviewItem> items;

  @override
  Future<List<ReviewItem>> read() async => items;

  @override
  Future<void> write(List<ReviewItem> next) async => items = next;
}

ReviewItem _item(String qid, DateTime dueAt) => ReviewItem(
      qid: qid,
      stage: 0,
      dueAt: dueAt,
      lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('期限の来た復習に答えると、1日の復習の回数に数える(無料枠は10問)', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = _MemoryReviewStore([for (var i = 0; i < 12; i++) _item('q$i', today)]);
    for (var i = 0; i < 12; i++) {
      await recordReviewResult('q$i', correct: true, at: now, store: store);
    }
    final free = await todayReviewQuota(isPremium: false);
    expect(free.used, 10); // 上限で止まる
    expect(free.remaining, 0);
    final premium = await todayReviewQuota(isPremium: true);
    expect(premium.remaining, isNull); // プレミアムは無制限
  });

  test('期限前の問題や、予定にない問題は数えない', () async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final store = _MemoryReviewStore([_item('later', tomorrow)]);
    await recordReviewResult('later', correct: true, at: now, store: store);
    await recordReviewResult('unknown', correct: true, at: now, store: store);
    expect((await todayReviewQuota(isPremium: false)).used, 0);
  });
}
