import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// テスト用の広告ゲート。何も表示せず、SDK も初期化しない。
class StubAdGate implements AdGate {
  @override
  Future<bool> maybeShowInterstitial(InterstitialTrigger trigger) async => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  void updateRules(AdRules rules) {}

  @override
  Widget banner(BannerPlacement placement) => const SizedBox.shrink();
}

/// 広告ゲートを差し込む override（`ProviderScope` / `ProviderContainer` の overrides に入れる）。
Override stubAdGateOverride() => adGateProvider.overrideWithValue(StubAdGate());
