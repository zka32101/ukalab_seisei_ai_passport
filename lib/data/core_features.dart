import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// ukalab_core の共通機能（更新ログ・当日チェックリスト）をこのアプリのデータにつなぐ部分。
/// 画面は `lib/screens/exam_prep_entry.dart` 側。

const String kExamId = 'seisei_ai_passport';
const String updateLogAsset = 'assets/features/update_log.jsonl';
const String checklistAsset = 'assets/features/checklist.jsonl';

/// 更新ログ（新しい順。未来の予定と90日より前は除く）。
Future<List<UpdateLogEntry>> loadUpdateLog({DateTime? now, AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(updateLogAsset);
  return recentUpdates(parseUpdateLogJsonl(text).entries, now ?? DateTime.now(), examId: kExamId);
}

/// 当日チェックリスト。全項目「公式で要確認」のまま出す（受験形式は断定しない）。
Future<List<ChecklistItem>> loadChecklist({AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(checklistAsset);
  return parseChecklistItemsJsonl(text).items.where((i) => i.examId == kExamId).toList();
}

/// 当日チェックリストのチェック状態（端末内）。
class ChecklistNotifier extends Notifier<ChecklistProgress> {
  static const _key = 'ukalab_seisei_ai_passport_exam_checklist_v1';
  late Future<void> _loaded;

  Future<void> get ready => _loaded;

  @override
  ChecklistProgress build() {
    _loaded = _load();
    return const ChecklistProgress();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_key);
      if (ids != null) state = ChecklistProgress({...ids, ...state.checkedIds});
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.checkedIds.toList()..sort());
    } catch (_) {}
  }

  /// 共通画面の変更通知から呼ぶ（チェック状態をまるごと置き換える）。
  Future<void> setProgress(ChecklistProgress p) async {
    await _loaded;
    state = p;
    await _save();
  }

  Future<void> restore(Iterable<String> ids) => setProgress(ChecklistProgress(ids.toSet()));

  Future<void> reset() => setProgress(const ChecklistProgress());
}

final checklistProvider =
    NotifierProvider<ChecklistNotifier, ChecklistProgress>(ChecklistNotifier.new);
