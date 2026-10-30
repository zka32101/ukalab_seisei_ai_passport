# 相互紹介（うかラボ cross_promo）

うかラボ各アプリの「他のアプリもチェック！」。`cross_promo_kit` を `ukalab_core` の薄いラッパー経由で使う（独自実装はしない）。

## このアプリの状態

| 項目 | 内容 |
|---|---|
| applicationId | `com.yourwish.ukalab.seisei_ai_passport`（`ukalab_core` の `kUkalabAppIds` に登録済み） |
| 起動時 init | `lib/main.dart` の `unawaited(UkalabCrossPromo.init())`（起動は止めない。失敗しても例外なし） |
| 配置 | 設定画面（`lib/screens/settings_screen.dart`）の「このアプリについて」の直上 |
| 子ども向け | 大人向け資格アプリのため `isChildDirected` は既定の false。保護者ゲートなし |
| テスト | `test/settings_cross_promo_test.dart`（掲載0件・Firebase未初期化でも例外なし） |

## 使い方（ラッパーの要点）

- `UkalabCrossPromo.init()`: Firebase 未初期化なら初期化し、続けて `CrossPromoService.init()`。2回呼んでも1回分のみ実行。
- `UkalabCrossPromoSection(currentAppId: ...)`: 掲載0件なら何も表示しない。カテゴリは「うかラボ」固定。
- 問題中・模擬試験中などの学習画面には置かない（設定画面のみ）。

## Firebase / Remote Config（運営作業）

- `android/app/google-services.json` はコミットしない。CI Secret `GOOGLE_SERVICES_JSON_BASE64` から注入（`docs/release_prep_log.md` 参照）。
- 掲載リストは Remote Config のキー `cross_promo_apps` に投入する。JSON の形式・検証・投入手順は cross_promo_kit の `docs/cross_promo_apps.json` と `docs/ROLLOUT.md` を参照（ここには複製しない）。
- 掲載するストアURL・アイコン等は、公開を確認してから運営が投入する。対象 Firebase プロジェクトも運営判断。コードからは変更できない。
- Play の Data Safety に Firebase 利用に伴う申告が必要。
