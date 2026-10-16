# アプリ内の非公式表示

## 表示場所
- 設定 → 「このアプリについて」(常に到達可能。`lib/screens/settings_screen.dart`)
- ホーム見出し下の短縮表示(既存。`lib/screens/home_screen.dart`)
- オンボーディング/初回起動画面はこのアプリには存在しないため対象外。

## 文言
`lib/unofficial_notice.dart` に定数として集約。
- 本アプリは、GUGA（一般社団法人生成AI活用普及協会）をはじめ、各試験の運営団体とは関係のない非公式アプリです。
- 掲載している試験名・団体名は、各権利者の商標または登録商標です。
- 問題はすべて独自に作成しています。

## 出典
ukalab_core の `docs/store_listing_drafts.md`(ブランチ docs/store-listing-drafts)の「共通ルール」と §3 生成AIパスポートの非公式表示、
および README / `content/exam/README.md` の倫理規定(非公式であることの明記)に関する記載。
「問題は独自作成」は README(例題・過去問を転載していない)に基づく。
提携・許諾を示す表現は使わない。名称・商標の使用許諾は未確認のまま。

## ローカライズ
アプリは日本語固定でローカライズ機構(arb 等)を持たないため、en は無し。

## テスト
`test/settings_version_test.dart`(表示有無と 320dp/文字2.0倍の溢れ)、`test/unofficial_notice_test.dart`。
