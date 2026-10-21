import 'package:app_common_kit/app_common_kit.dart' show entitlementStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart' show characterAppIdProvider, characterPremiumProvider;

/// ukalab_core に登録されているこのアプリの appId（資格専用キャラ「ヒラリ」の出し分けに使う）。
/// アプリ内の他の識別子（'seisei_ai_passport' など）とは別。
const String kCharacterAppId = 'gen_ai_passport';

/// 資格専用キャラの選択画面へ渡す override。プレミアムかは権利状態に追従する。
final List<Override> characterOverrides = [
  characterAppIdProvider.overrideWithValue(kCharacterAppId),
  characterPremiumProvider.overrideWith(
    (ref) => ref.watch(entitlementStateProvider).valueOrNull?.hasPremium ?? false,
  ),
];
