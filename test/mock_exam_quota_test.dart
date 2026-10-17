import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_seisei_ai_passport/data/mock_exam_quota.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('無料版は月に1回だけ模擬試験を始められる', () async {
    final now = DateTime(2026, 10, 17);
    final q1 = await mockExamQuota(isPremium: false, clock: () => now);
    expect(await q1.tryConsume(), isTrue);
    // 保存されるので、作り直しても同じ月は使い切り
    final q2 = await mockExamQuota(isPremium: false, clock: () => now);
    expect(await q2.tryConsume(), isFalse);
  });

  test('月が変わると、また1回使える', () async {
    final q1 = await mockExamQuota(isPremium: false, clock: () => DateTime(2026, 10, 31));
    expect(await q1.tryConsume(), isTrue);
    final q2 = await mockExamQuota(isPremium: false, clock: () => DateTime(2026, 11, 1));
    expect(await q2.tryConsume(), isTrue);
  });

  test('プレミアムは回数に制限がない', () async {
    final now = DateTime(2026, 10, 17);
    for (var i = 0; i < 5; i++) {
      final q = await mockExamQuota(isPremium: true, clock: () => now);
      expect(await q.tryConsume(), isTrue);
    }
  });
}
