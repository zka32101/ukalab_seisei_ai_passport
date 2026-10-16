import 'package:app_common_kit/app_common_kit.dart' show AdUnitIds;

/// 本番の広告ユニットID（Android）。ビルド時に `--dart-define` で渡す。コミットしない。
/// `AD_BANNER_ID` / `AD_INTERSTITIAL_ID` / `AD_REWARDED_ID`（形式 `ca-app-pub-.../...`）。
const adBannerId = String.fromEnvironment('AD_BANNER_ID');
const adInterstitialId = String.fromEnvironment('AD_INTERSTITIAL_ID');
const adRewardedId = String.fromEnvironment('AD_REWARDED_ID');

/// Google が公開しているテスト用の広告ユニットID（Android）。
const _testAndroid = AdUnitIds(
  banner: 'ca-app-pub-3940256099942544/6300978111',
  interstitial: 'ca-app-pub-3940256099942544/1033173712',
  rewarded: 'ca-app-pub-3940256099942544/5224354917',
);

const _noAds = AdUnitIds(banner: '', interstitial: '', rewarded: '');

/// 実行環境に応じた広告ユニットIDを返す。
///
/// - Web・iOS・その他: 空のID（広告を出さない。今は Android のみ対応）。
/// - Android のデバッグ・profile: テスト広告。開発中に本物の広告を表示・クリックして
///   不正クリック扱いになるのを避ける。
/// - Android のリリース: 渡された本番ID。未指定（空）なら空のIDにして広告を出さない
///   （テストIDのままリリースすると AdGate が例外にするため）。
AdUnitIds adUnitIdsFor({
  required bool isWeb,
  required bool isAndroid,
  required bool isRelease,
  String banner = adBannerId,
  String interstitial = adInterstitialId,
  String rewarded = adRewardedId,
}) {
  if (isWeb || !isAndroid) return _noAds;
  if (!isRelease) return _testAndroid;
  return AdUnitIds(banner: banner, interstitial: interstitial, rewarded: rewarded);
}
