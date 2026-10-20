# うかラボ 生成AIパスポート

生成AIパスポート試験（主催: GUGA〈一般社団法人生成AI活用普及協会〉）の学習アプリ。追加モジュールとして生成AI導入実務者検定（GAIP）を将来対象とする。

**本アプリは、GUGAおよび生成AI活用普及協会とは一切関係のない非公式の学習アプリです。**

## 位置づけ

```
本リポジトリ（薄いアプリ） → yourwish_kentei（試験エンジン） → app_common_kit（共通部品）
```

本リポジトリが持つのは ExamConfig（試験定義）・問題データ・テーマ・ストア設定・アプリ本体のUI実装（`lib/`）のみ。共通の仕組みは `yourwish_kentei` / `app_common_kit` に実装されており、タグ固定（`ref: vX.Y.Z`）で参照する。

- [`zka32101/yourwish_kentei`](https://github.com/zka32101/yourwish_kentei)（現在 `v0.12.0`）
- [`zka32101/app_common_kit`](https://github.com/zka32101/app_common_kit)（現在 `v0.8.0`）

## 現在の状態（2026-10-07 時点）

- リリース順（決定66）: 第1陣は G検定 → データマネジメント試験 → **本アプリ** → 危険物乙4 → 簿記3級
- 学習体験の「型」は `yourwish_kentei` 側に実装され続けている（v0.12.0時点でデータを要する型が12種類。他に正答率などの既存データだけで動くロジック専用の型が2種類）。機械学習ラボ・ニューラルネット組み立て・評価指標ラボ・画像認識の中身を見る・手法の選び方（1章向け）、境界線スライダー・Transformerの注意の可視化・AI倫理ケース・ストーリー型エンジン・温度の実験室・推しの答案を添削・学習の失敗図鑑の12種類全てで、本リポジトリ向けの初期データを作成済み（CIにも統合済み）。本アプリ独自の体験型機能（プロンプト組み立てパズル・これ入力していい？・ハルシネーション見破り・AIの歴史タイムライン）に対応する専用モデルはまだ無い（詳細は`content/exam/README.md`）
- シラバスは GUGA公式「2027年2月試験より適用」版（新シラバス、全5章。3章がAIエージェントとして独立）を前提に設計し直し済み。公式サイトでの最終確認も実施済み（詳細は `content/exam/README.md`）
- `content/exam/` に ExamConfig と、問題データ518問（1章79／2章125／3章98／4章144／5章72）・用語データ133語を配置。いずれも提案配分・主要概念の抽出は完了しているが、**本番配信用の確定版ではない**（運営者による内容確認・商標使用許諾の確認が未着手）
- 運営者からGUGA公式シラバスPDF（2027年2月試験より適用、全5章の大項目・中項目・学習目標・学習項目・詳細キーワード）の提供を受け、`questions.jsonl`の全`topicId`（400件、1問1トピック）と突き合わせて網羅性を確認した。全5章とも公式シラバスの学習項目をほぼ完全にカバーしていることを確認済み。照合で見つかった軽微な不足3件（1章「ドロップアウト」・2章「Operator/Codex」・4章「ディープフェイクによるなりすましリスク」）は問題を追加して解消済み（sap-0401〜0403）
- 画期的な機能①〜④（プロンプト組み立てパズル・これ入力していい？・ハルシネーション見破り・AIの歴史と最新動向タイムライン）は、専用モデルの実装を待たずにコンテンツを先行作成済み（`content/exam/`配下、詳細はREADMEを参照）。⑤用語マップは用語データで対応。⑥今月のAI動向は`yourwish_kentei`に実装された`AiNewsItem`モデルに対応するデータを配置済みで、CIにも統合済み（`content/news/`配下、詳細は`content/exam/README.md`）
- アプリアイコンはシンボル`passport_ai`・短縮表記「AIパス」で最終案を確定（`store/icon/README.md`）。`app_common_kit`への取り込みも完了済み
- 新シラバスで新設された3章「AIエージェント」向けに、既存の画期的な機能・体験型では未対応だったギャップを埋める新規機能案（RAGパイプライン構築パズル・エージェントへの権限委任シミュレーター・改訂差分ドリル）を企画し、サンプルデータを先行作成済み（`content/exam/`配下、詳細は`content/exam/README.md`）。いずれも企画段階で、`yourwish_kentei`側への型実装提案は未着手
- 企画設計書の「画期的アイディア」5案（温度の実験室・RAGを組み立てる・著作権の分かれ道・任せていい？権限設計・改訂差分ドリル）は、既存の境界線スライダー（`boundary_scenarios.jsonl`に「著作権の分かれ道」シナリオを追加）も含め全て対応完了
- アプリ本体のUI実装を、G検定アプリ（`ukalab-g-kentei`）のパターンに合わせて拡張（`flutter_riverpod`導入、`UkalabShell`による5タブ構成「ホーム/学ぶ/模擬/記録/設定」）。`lib/data/exam_repository.dart`（`FutureProvider`での試験データ読み込み）・`lib/screens/`（各タブ）に分割。学ぶタブは演習10問（`PracticeSession`）、模擬タブは本試験形式の採点（`scoreMockExam`、合格ラインは非公開のため70%を目安表示）。`flutter build web --no-web-resources-cdn`でのビルドとPlaywright(Chromium)での全タブの表示・操作を確認済み。推し・コイン・衣装・権利管理・広告ゲート等の機能は未実装
- 記録タブに間隔反復（Leitner方式、`yourwish_kentei`の`Srs`/`SrsItem`）を実装。学ぶタブで解答するたびに`lib/data/srs_repository.dart`（`AsyncNotifier`＋`shared_preferences`で端末内保存）に記録し、記録タブでは復習時期が来た問題数・定着済み問題数を表示。「復習を始める」から`PracticeSession`の`priorityQids`（復習対象を先頭固定）・`mode: weak`で学ぶタブ相当の画面に遷移する
- 記録タブに苦手分析を追加。解答のたびに問題ID単位の解答回数・正解数（`AnswerStat`）も`srs_repository.dart`に記録し、`Question.subjectId`（章）ごとに集計。正答率が低い章を最大3件表示し、各行をタップするとその章の復習（不正解だった問題を優先、全問正解なら解答済み全問）に直接遷移する
- 模擬試験の出題にも苦手科目優先を反映。`SrsStore.statsBySubject`（記録タブと共用）から科目別正答率を算出し、正答率が低い科目ほど出題されやすくなるよう重み付け抽選（`_pickWeighted`）で60問を選ぶ。解答実績が無い科目・解答実績自体が無い場合は従来どおり一様ランダムと同じ
- ホームタブに「推しの答案を添削」（画期的な機能・共通基盤の型③、`yourwish_kentei`の`MisconceptionScenario`、`app_common_kit`の`TeachMascotWidget`）を実装。`lib/data/misconception_repository.dart`で`teach_mascot_scenarios.jsonl`（10場面）を読み込み、`lib/screens/teach_mascot_screen.dart`で1場面ずつ表示する
- ホームタブに「学習の失敗図鑑」（共通基盤の型⑦、`yourwish_kentei`の`FailureCase`、`app_common_kit`の`FailureGalleryWidget`）を実装。`lib/data/failure_gallery_repository.dart`で`failure_gallery_cases.jsonl`（10症例）を読み込み、`lib/screens/failure_gallery_screen.dart`で学習曲線から症状→処方の2段階選択→解説を1症例ずつ表示する
- ホームタブに「用語マップ」（画期的な機能⑤、`yourwish_kentei`の`Term`、`app_common_kit`の`TermMapWidget`/`TermCard`）を実装。`lib/data/term_repository.dart`で`terms.jsonl`（133語）を読み込み、`lib/screens/term_map_screen.dart`でAIの歴史（`era`付き69語）を時代区分のタイムライン、それ以外を関連でつながる地図で表示。タップで用語カード（ボトムシート）を開き、関連用語はカードを開き直し・関連問題は`priorityQids`で学ぶタブ相当の画面に遷移する
- ホームタブに、`app_common_kit`に既製UIウィジェットがある残り4種の共通基盤体験型を実装。いずれもホームの入り口カードから遷移する専用画面＋`FutureProvider`のリポジトリ（データは全て既存、本番配信用の確定版ではない）:
  - 「境界線スライダー」（型①）: `BoundaryScenario`（`boundary_scenarios.jsonl`、21場面、著作権の分かれ道シナリオ含む）・`BoundarySliderWidget`
  - 「評価指標ラボ」（画期的な機能3）: `ConfusionMatrixScenario`（`confusion_matrix_scenarios.jsonl`、20場面）・`ConfusionMatrixLabWidget`
  - 「温度の実験室」（予測→実行、型②）: `PredictRunScenario`（`predict_run_scenarios.jsonl`、9場面、bayes/expectedValue/normalDistributionの3種）・`PredictRunWidget`
  - 「今日やる3つ」（最短ルートプランナー、型④）: データファイルを持たないロジック専用の型。記録タブと共用の`SrsStore.statsBySubject`から科目別正答率を算出し、`RoutePlanner.plan()`で弱点・配点から3科目を提案する`RoutePlannerWidget`
- ホームタブに「今月のAI動向」（画期的な機能⑥、`yourwish_kentei`の`AiNewsItem`）を実装。`app_common_kit`に既製UIウィジェットが無いため`lib/screens/ai_news_screen.dart`でカード一覧を自作。`lib/data/ai_news_repository.dart`で`news.jsonl`（3件）を新しい順に読み込み、章タグ・要約を表示（「試験に出そう」バッジは非公式アプリ方針により表示しない）。`url_launcher`を追加し「一次情報を見る」で出典URLを外部ブラウザで開き、`relatedQuestionId`がある場合は「関連問題を解く」から学ぶタブ相当の画面に遷移する
- ホームタブに「章ごとの解説読み物」（教科書的なまとめページ）を実装。`ukalab_core`の`ChapterReading`モデル・`app_common_kit`の`ChapterReadingWidget`として共通基盤化し、G検定アプリと共用する。`content/exam/reading.jsonl`（5章分）を`lib/data/reading_repository.dart`で読み込み、`lib/screens/reading_screen.dart`で節（見出し＋本文）ごとに表示、末尾から関連用語・関連問題にも遷移できる
- GUGA公式サイトで2027年試験向けシラバスの「大幅改訂」が告知された（公式テキストの発行元もGUGAから翔泳社に変更）。出題範囲の詳細が未確認のため問題データの作り直しは時期尚早だが、新旧の問題を区別できるよう`questions.jsonl`・`seisei_ai_passport.json`に`syllabusVersion`フィールドを追加済み。`yourwish_kentei`側の型実装提案は`content/exam/proposal/`に作成済み（詳細は`content/exam/README.md`）
- `yourwish_kentei`側への型実装提案2件をIssue起票済み: [Issue #27](https://github.com/zka32101/yourwish_kentei/issues/27)（`AiTimelineEvent`型）・[Issue #28](https://github.com/zka32101/yourwish_kentei/issues/28)（`Question`/`ExamConfig`への`syllabusVersion`追加）。RAGパイプライン構築パズル等3章向け新規提案3件はまだ未起票

## ドキュメント

設計の詳細は Google Drive の設計書フォルダを参照（このリポジトリには含めない）:
- `ukalab_生成AIパスポート_企画設計書_v0_1.md`（本体）
- `ukalab_生成AIパスポート_シラバス確認_v1_1.md`（GUGA公式シラバスの新旧比較）
- `ukalab_生成AIパスポート_企画設計書_v0_3差分（新シラバス対応）.md`（新シラバスへの差分）
- `ukalab_生成AIパスポート_企画設計書_v0_4差分（実装進捗・2026-10-04）.md`（本リポジトリ側の実装・コンテンツ先行作成の進捗）
- `ukalab_生成AIパスポート_シラバス確認_v1_2差分（GUGA公式サイト確認結果）.md`（受験規約・商標・例題公開状況の確認結果）
- `ukalab_生成AIパスポート_競合調査_追補_v1_0（Google Play・新規アプリ）.md`（Google Play競合の追加調査）
- `ukalab_共通基盤_各資格アプリ向けガイド_v0_2.md`（共通基盤の使い方。新しい資格アプリを作る人向け）

## 開発環境の注意

Windows実機では日本語パスでビルドが失敗するため、英語パスにクローンすること。詳細は上記ガイド §6 を参照。
