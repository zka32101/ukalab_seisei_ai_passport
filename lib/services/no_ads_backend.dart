import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/widgets.dart';

/// 広告を出さない [AdsBackend]。広告SDKが使えない Web 版で使う。
class NoAdsBackend implements AdsBackend {
  @override
  Future<bool> initialize(AdConfig config) async => false;

  @override
  Future<void> preloadInterstitial() async {}

  @override
  bool get isInterstitialReady => false;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  Widget buildBanner(BannerPlacement placement) => const SizedBox.shrink();
}
