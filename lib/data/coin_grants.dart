import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'oshi_recap.dart';

/// コイン・衣装の保存キーと資格ID。
const kCoinAppKey = 'gen_ai_passport';

/// 連続学習でコインが付く日数（core の CoinRules と同じ 7/30/100）。
const kStreakCoinMilestones = [7, 30, 100];

/// 学習コイン・衣装（着替え・ショップ）のサービスを差し込む override。
/// 無いと coinServiceProvider 未設定で着替え・ショップが開けない。
/// ショップには、この資格の通常衣装（コイン購入）を並べる。
Future<List<Override>> coinOutfitOverrides(String appKey) async {
  final coinService = CoinService(
    store: SharedPreferencesCoinStore(appKey),
    shop: OutfitCatalog.shopItems([UkalabCert.genAiPassport]),
  );
  await coinService.load();
  final outfitService = OutfitService(store: SharedPreferencesOutfitStore(appKey));
  await outfitService.load();
  return [
    coinServiceProvider.overrideWithValue(coinService),
    outfitServiceProvider.overrideWithValue(outfitService),
  ];
}

/// コインを付与する。付与に失敗しても（サービス未設定・保存失敗など）学習は止めない。
void grantCoin(WidgetRef ref, CoinEvent event) {
  try {
    ref.read(coinProvider.notifier).grant(event).catchError((_) => null);
  } catch (_) {
    // コインは付加機能。出題・採点を妨げない。
  }
}

/// 解答の記録後に呼ぶ。新しい問題のコインと、連続学習の節目のコイン。
void grantAnswerCoins(WidgetRef ref, String qid, List<ProgressRecord> records) {
  grantCoin(ref, CoinEvent.newQuestion(qid));
  final now = DateTime.now();
  // 履歴への追記は非同期のため、今日の記録がまだ無ければ「今日の分」を足して数える。
  final studiedToday =
      records.any((r) => r.at.year == now.year && r.at.month == now.month && r.at.day == now.day);
  final days = currentStreakDays(records, now) + (studiedToday ? 0 : 1);
  if (kStreakCoinMilestones.contains(days)) {
    grantCoin(ref, CoinEvent.streak(days));
  }
}
