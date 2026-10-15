import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart' show PeerStatsSettings, ProgressRecord;

import 'oshi_recap.dart';

/// PeerStats（匿名集計）の下準備。**送信は一切しない**。
///
/// (a) アプリのローカル値を取り出す関数と (b) 参加設定の保存だけを持つ。
/// どちらも現時点ではどこにも接続しない（PeerStatsSink・installId・Firestore は未実装）。

/// 端末内の値のうち、将来「匿名の値」として使えるもの。取り出すだけで、外へは出さない。
class PeerLocalValues {
  const PeerLocalValues({
    required this.streakDays,
    required this.totalAnswers,
    required this.distinctQuestions,
    this.examDate,
  });

  final int streakDays;

  /// 延べ回答数（同じ問題を複数回解いた分も数える。`records.length`）。
  final int totalAnswers;

  /// ユニーク問題数（解答履歴の qid の種類数）。
  final int distinctQuestions;

  /// 試験日（未設定は null）。
  final DateTime? examDate;
}

/// 延べ回答数。既存の `oshiGrowthProgressFor(...).totalAnswered` と同じ定義。
int peerTotalAnswers(List<ProgressRecord> records) => records.length;

/// ユニーク問題数。
int peerDistinctQuestions(List<ProgressRecord> records) =>
    {for (final r in records) r.qid}.length;

/// 既存の解答履歴・試験日からローカル値を作る（読み取りのみ）。連続日数は既存の [currentStreakDays]。
PeerLocalValues peerLocalValuesFrom({
  required List<ProgressRecord> records,
  required DateTime now,
  DateTime? examDate,
}) =>
    PeerLocalValues(
      streakDays: currentStreakDays(records, now),
      totalAnswers: peerTotalAnswers(records),
      distinctQuestions: peerDistinctQuestions(records),
      examDate: examDate,
    );

/// 参加設定の保存先（shared_preferences）。既定は OFF。キーはアプリ固有。
class SharedPrefsPeerStatsSettings implements PeerStatsSettings {
  static const key = 'ukalab_seisei_ai_passport_peer_stats_sharing_v1';

  @override
  Future<bool> isSharingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
  }
}

final peerStatsSettingsProvider =
    Provider<PeerStatsSettings>((ref) => SharedPrefsPeerStatsSettings());
