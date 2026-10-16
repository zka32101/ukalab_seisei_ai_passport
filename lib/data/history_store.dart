import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 1問ごとの解答履歴（[ProgressRecord]）を端末内に保存する。
///
/// 弱点ドリル・試験直前・履歴CSVの元データ。個人を特定する情報は持たない。
/// 追記・上限・保存形式は ukalab_core（[appendHistory] など）。ここは端末への保存だけを担う。
class HistoryNotifier extends Notifier<List<ProgressRecord>> {
  static const _key = 'ukalab_seisei_ai_passport_history_v1';

  late Future<void> _loaded;

  /// 保存済みの履歴を読み終えたとき。
  Future<void> get ready => _loaded;

  @override
  List<ProgressRecord> build() {
    _loaded = _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final records = decodeHistory(prefs.getString(_key));
    // 読み込み中に追加された分を失わないよう、先頭に足す。
    if (records.isNotEmpty) state = [...records, ...state];
  }

  /// 解答を1件記録する。[ms] は回答にかかった時間（ミリ秒、不明なら省略）。
  Future<void> record(
    Question q, {
    required bool correct,
    int? ms,
    DateTime? at,
  }) async {
    await _loaded;
    state = appendHistory(state, historyRecordFor(q, correct: correct, ms: ms, at: at));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHistory(state));
  }

  /// 直近の誤答記録（[qid]）に原因ラベルを後付けして保存する。[cause] が null なら外す。
  Future<void> setCause(String qid, WrongCause? cause) async {
    await _loaded;
    state = attachCauseToLatest(state, qid, cause);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHistory(state));
  }

  /// 直近の [qid] の記録を、自己申告で正解に直して保存する（自由入力の打ち間違い救済）。
  Future<void> markLatestCorrect(String qid) async {
    await _loaded;
    state = markLatestRecordCorrect(state, qid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHistory(state));
  }

  /// バックアップの読み込み時に呼ぶ。[records] で上書きする。
  Future<void> replace(List<ProgressRecord> records) async {
    await _loaded;
    state = records;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeHistory(records));
  }

  /// 解答履歴をすべて消す。
  Future<void> reset() async {
    await _loaded;
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// 直近の [qid] の不正解の記録を正解に直す（原因ラベルは外す）。無ければそのまま返す。
List<ProgressRecord> markLatestRecordCorrect(List<ProgressRecord> records, String qid) {
  for (var i = records.length - 1; i >= 0; i--) {
    final r = records[i];
    if (r.qid != qid) continue;
    if (r.correct) return records;
    final next = [...records];
    next[i] = ProgressRecord(
      qid: r.qid,
      subjectId: r.subjectId,
      correct: true,
      at: r.at,
      topicId: r.topicId,
      subtopicId: r.subtopicId,
      ms: r.ms,
    );
    return next;
  }
  return records;
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<ProgressRecord>>(HistoryNotifier.new);
