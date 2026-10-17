import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 無料版の模擬試験の回数制限（方針 D6。標準値は月1回。値は暫定で公開後の実測で見直す）。
/// プレミアム（premium）なら無制限。使用回数は端末内（SharedPreferences）に保存する。
class _PrefsKeyValueStore implements KeyValueStore {
  _PrefsKeyValueStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// 模擬試験の回数制限を返す。
Future<UsageQuota> mockExamQuota({
  required bool isPremium,
  DateTime Function()? clock,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return FreeTierLimits.standard.mockExamQuota(
    isPremium: isPremium,
    store: _PrefsKeyValueStore(prefs),
    clock: clock,
  );
}

/// 「今日の復習」の1日の回数制限（方針 D6。標準値は1日10問。値は暫定）。
/// 数えるのは、復習の期限が来ていた問題に答えた回数。プレミアムなら無制限。
/// 制限は「今日の復習」の案内だけにかける（間違いノート自体は無料のまま）。
Future<UsageQuota> todayReviewQuota({
  required bool isPremium,
  DateTime Function()? clock,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return FreeTierLimits.standard.reviewQuota(
    isPremium: isPremium,
    store: _PrefsKeyValueStore(prefs),
    clock: clock,
  );
}
