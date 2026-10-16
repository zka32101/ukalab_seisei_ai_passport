/// RevenueCat の公開SDKキー。ビルド時に `--dart-define` で渡す。コミットしない。
/// Android は `RC_GOOGLE_KEY=goog_...`、iOS は `RC_APPLE_KEY=appl_...`。
const rcGoogleKey = String.fromEnvironment('RC_GOOGLE_KEY');
const rcAppleKey = String.fromEnvironment('RC_APPLE_KEY');

/// 実行中のプラットフォームで使う RevenueCat の公開SDKキーを返す。
/// Web・その他のプラットフォーム、または該当キーが未指定（空）のときは null
/// （呼び出し側は従来どおり仮の購入サービスを使う）。
String? revenueCatKeyFor({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
  String googleKey = rcGoogleKey,
  String appleKey = rcAppleKey,
}) {
  if (isWeb) return null;
  final String key;
  if (isAndroid) {
    key = googleKey;
  } else if (isIOS) {
    key = appleKey;
  } else {
    return null;
  }
  return key.isEmpty ? null : key;
}
