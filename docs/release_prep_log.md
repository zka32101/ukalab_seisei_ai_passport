# リリース準備ログ（生成AIパスポート）

本ドキュメントは、本番リリースに向けて実施した作業の記録。

## 1. セキュリティ・匿名化レビュー

OWASP MASVS準拠チェック・匿名化(OPSEC)チェックを実施。

- APIキー・シークレットのハードコードなし（GitHub Secrets経由）
- 証明書類の平文混入なし
- 専用GitHubアカウント（zka32101）で統一
- http平文通信なし
- print/debugPrint残留なし
- Firebase未使用（該当なし）

対応した未対応項目:
- LICENSE追加（All Rights Reserved、Copyright: Petit Works Apps）
- `.github/dependabot.yml` 追加（pub・github-actionsの週次脆弱性チェック）
- `ci.yml`・`validate_content.yml` に `permissions: contents: read` を明記

## 2. バージョン・CHANGELOG

- `pubspec.yaml` バージョンを `0.1.0` → `1.0.0+1` に昇格（初回リリース）
- `CHANGELOG.md` を新規作成

## 3. Androidパッケージ名

- `com.ukalab.ukalab_seisei_ai_passport` → `com.yourwish.ukalab.seisei_ai_passport` に変更
  （G検定 `com.yourwish.ukalab.g_kentei` と同じ階層構造に統一）
- `MainActivity.kt` のパッケージ宣言・配置ディレクトリも追従

## 4. リリース署名・AABビルド

- リリース用keystore（`upload`、storeFile/keyAlias/keyPassword）を新規生成し、
  Google Driveに保管（紛失厳禁、紛失すると同じアプリを二度と更新不可）
- `android/app/build.gradle.kts` にリリース署名設定を追加
  （`android/key.properties`、またはGitHub Actions SecretsのUPLOAD_KEYSTORE_BASE64・
  UPLOAD_STORE_PASSWORD・UPLOAD_KEY_ALIAS・UPLOAD_KEY_PASSWORDから読み込み）
- `.github/workflows/build-aab.yml`（`workflow_dispatch`）を追加
- `android/app/build.gradle.kts` に `kotlin-android` プラグインを追加
  （未適用でGradleコンパイルエラーが発生していた）
- `android/app/proguard-rules.pro` を追加
  （AGP 9.1.0でR8縮小化がデフォルト有効になり、このファイルが必須だった）
- 2回のビルド失敗を修正後、AABビルドは成功

## 5. Playストア掲載用説明文（SEO強化版）

### 短い説明
生成AIパスポート 対策・問題集。ChatGPT等の生成AI資格・GAIP検定の模擬試験＆解説で合格を目指す

### 詳しい説明
うかラボ 生成AIパスポートは、一般社団法人生成AI活用普及協会（GUGA）主催の生成AIパスポート試験合格を目指す、問題集・模擬試験アプリです。ChatGPTをはじめとする生成AIの活用・リスク・ガイドラインを学べます。追加モジュールとして生成AI導入実務者検定（GAIP）にも対応。
※本アプリはGUGAとは無関係の非公式アプリです。

【こんな方におすすめ】
- 生成AIパスポート 独学で合格したい方
- ChatGPT・生成AIの資格を取りたい方
- 生成AI導入実務者検定（GAIP）対策をしたい方
- 業務で生成AIを活用するための知識を身につけたい方

【主な機能】

◆ 問題演習（学ぶ）
- 生成AI・ChatGPT活用・AIリスクの分野別に問題演習ができます
- 間隔反復（忘却曲線に基づく復習タイミング）で、効率よく記憶に定着
- 解答実績から苦手な分野を優先的に出題

◆ 模擬試験
- 本試験相当の形式で実力を確認
- 結果画面で正答率を確認

◆ 章ごとの解説読み物（教科書代わりに）
- 生成AIの基礎・活用方法・リスクを体系的に整理
- 関連する用語・問題へすぐアクセス

◆ 今月のAI動向
- 生成AIに関する最新トピックをキャッチアップ

◆ 記録・学習管理
- 解答履歴から復習予定（間隔反復）を自動管理
- 学習の振り返りがしやすい記録タブ

◆ プレミアム機能（アプリ内購入）
- カスタム模擬試験（出題する分野・問題数を指定）
- 模擬試験の成長グラフ
- 解説読み物の読み上げ（ながら学習）
- 広告非表示

【ご利用にあたって】
- 学習データ・進捗は端末内に保存されます

生成AIパスポート・GAIPの合格に向けて、問題集・模擬試験で効率的な学習を一緒に進めましょう。

## 6. データ収集・セキュリティの現状（調査結果）

- 広告SDK（AdMob）: 未配線。現時点でネットワーク経由の個人データ送信は実質ゼロ。
- 購入（RevenueCat）・Firebase（匿名集計・コイン同期・学習データ引き継ぎ）:
  コード実装済みだが `FakeEntitlementService` 等を使用しており未配線（外部送信なし）。
  配線する場合は事前にPlay Consoleのデータセーフティフォームの申告内容を更新すること。
- クラッシュレポート・アナリティクスSDK: 未使用。
- 学習進捗・履歴等: すべて端末内（shared_preferences）保存のみ。

リリース前に対応が必要な項目:
- プライバシーポリシーURLの用意（Play Console提出必須）
- 広告SDKを配線する場合はデータセーフティフォームの広告ID申告を追加
