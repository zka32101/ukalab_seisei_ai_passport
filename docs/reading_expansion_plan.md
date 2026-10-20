# 章ごとの解説読み物 拡充計画

本アプリは非公式の学習アプリです。読み物は全て自作で、公式資料・市販教材の転載や近い言い換えをしません。

## 状態（重要）

- 拡充分は **AI生成の下書き**です。**専門家レビュー前**で、内容の正確さは未確認です。
- データ上の印: `source` は `original`、`sourceRef` に `ai-draft` を含めています（問題データの `tags: ["ai-draft"]` に相当。読み物のスキーマには `tags` が無いため `sourceRef` で表します）。
- 公開前に、専門家（または運営者）が各レコードを確認し、確認済みになったら `sourceRef` の `ai-draft` の記載を外します（手順は `docs/expert_review/README.md` に合わせる）。
- 法令・権利・ガバナンスに触れる章（4章）は、特にレビューを優先します。説明は一般的な考え方にとどめ、法的助言ではない旨を本文に入れています。

## 方針

- スキーマは現状のまま（`ChapterReading`）。1章に複数レコードを置き、`reading.jsonl` の末尾に追加します。画面（読み物一覧）は一覧に項目が増えるだけで、画面コードは変更しません。
- 既存の章まとめ（`reading-ch1`〜`reading-ch5`）は概観として残します。
- 生成AIは変化が早いため、特定の製品名・バージョン・数値・日付は断定せず、仕組みと考え方を中心に書きます。
- 禁止表現: 「公式」「本試験相当」「合格保証」「試験に出る」。テスト（`test/reading_content_test.dart`）で拡充分を検査します。
- 1レコード 4〜6節、1節 約150〜200字、具体例を1つ以上含む平易な文章にします。タイトルは30字以内（一覧で折り返しすぎないように）。

## ID・参照の付け方

- `readingId`: `reading-ch{章}-{連番2桁}`（例: `reading-ch2-03`）。連番は下表の番号に固定します（欠番は未執筆）。
- `subjectId`: `ch1`〜`ch5`（`seisei_ai_passport.json` の subjectId）。
- `relatedTermIds`: `terms.jsonl` の `termId`。その読み物で解説する用語を5〜8個。
- `relatedQuestionIds`: `questions.jsonl` の `qid`。下表の「問題の topicId」に該当する問題の `qid` を、`topicId` で検索して付けます。ai-draft の新形式問題（sap-0479〜）よりも、既存の問題を優先します。
- 全IDは実在するものだけ。`test/reading_content_test.dart` と CI の `validate_content` で検査します。
- `contentVer`: `YYYY.MM.DD-draftN`（レビュー後に確定版へ）。

## 章立て一覧（全24章）

状態: 済 = 第1弾で執筆（8章）、未 = 残り（16章）。節数は想定。

### 1章 AIの基礎と歴史（5）

| ID | タイトル | 主な topicId | 主な termId | 節 | 状態 |
|---|---|---|---|---|---|
| reading-ch1-01 | 機械学習の3つの学び方 | supervised-learning, unsupervised-learning, reinforcement-learning, semi-supervised, classification-regression, clustering, ml-paradigm-selection | machine-learning, supervised-learning, unsupervised-learning, reinforcement-learning, semi-supervised-learning | 5 | 済 |
| reading-ch1-02 | 学習の仕組み：損失・勾配・誤差逆伝播 | loss-function, gradient-descent, backpropagation, activation-function, nn-layers, nn-training-flow-order | neural-network, loss-function, gradient-descent, backpropagation, activation-function, deep-learning | 5 | 未 |
| reading-ch1-03 | 過学習と汎化を理解する | overfitting, overfitting-sign, regularization, dropout, early-stopping, generalization, transfer-learning | overfitting, generalization, regularization, early-stopping, transfer-learning | 6 | 済 |
| reading-ch1-04 | 代表的なモデルの得意分野 | cnn, rnn, lstm, gan, vae, vae-vs-gan, generative-discriminative-choice | cnn, rnn, lstm, gan, vae | 5 | 未 |
| reading-ch1-05 | AIの歴史：ブームと冬 | dartmouth, first/second/third-ai-boom, ai-winter, expert-system, knowledge-base, singularity | dartmouth, ai-boom-waves, ai-winter, expert-system, knowledge-base, singularity | 5 | 未 |

### 2章 生成AI（5）

| ID | タイトル | 主な topicId | 主な termId | 節 | 状態 |
|---|---|---|---|---|---|
| reading-ch2-01 | トークンとコンテキストの基本 | tokenization, subword-tokenization, tokenizer-language-difference, context-window(-limit), token-based-pricing, embedding, next-token-prediction | token, tokenization, embedding, next-token-prediction, context-window, llm | 6 | 済 |
| reading-ch2-02 | Transformerと注意の仕組み | transformer, self-attention, qkv, attention-qkv-role, encoder-decoder-role, scaling-laws, emergent-ability, long-range-dependency | transformer, self-attention, qkv, encoder-decoder, scaling-law, emergent-ability, nlp | 5 | 未 |
| reading-ch2-03 | 学習の段階とモデルの調整 | pretraining, foundation-model, instruction-tuning, rlhf, reward-model, pretraining-finetuning-rlhf-order, finetuning-basic | pretraining, foundation-model, instruction-tuning, rlhf, reward-model, finetuning, open-weight | 6 | 済 |
| reading-ch2-04 | 出力のゆらぎとハルシネーション | temperature-topp, temperature-*-usecase, hallucination(-cause/-mitigation-basic), knowledge-cutoff, reasoning-model, system-vs-user-prompt | temperature-topp, hallucination, knowledge-cutoff, reasoning-model, system-prompt | 5 | 未 |
| reading-ch2-05 | 画像・音声・マルチモーダル | diffusion-model, latent-diffusion, image-inpainting, multimodal, voice-cloning, deepfake, image-c2pa-provenance | diffusion-model, multimodal, deepfake, c2pa | 5 | 未 |

### 3章 AIエージェント（5）

| ID | タイトル | 主な topicId | 主な termId | 節 | 状態 |
|---|---|---|---|---|---|
| reading-ch3-01 | エージェントの基本構造 | agent-vs-chatbot-diff, agent-llm-core-structure, agent-plan-replan-cycle, task-decomposition, agent-memory, short-long-term-memory | ai-agent, task-decomposition, agent-memory, system-prompt | 5 | 未 |
| reading-ch3-02 | RAGの基本の流れ | rag, rag-def, rag-why, chunking, vector-db, semantic-search, rag-vs-finetuning | rag, vector-database, chunking, semantic-search, embedding, knowledge-cutoff | 6 | 済 |
| reading-ch3-03 | RAGの精度を上げる工夫 | query-rewriting, reranking, hybrid-search, metadata-rag, graph-rag, knowledge-graph-def, agentic-rag, advanced-rag | query-rewriting, reranking, hybrid-search, graph-rag, knowledge-graph, agentic-rag | 5 | 未 |
| reading-ch3-04 | ツール連携とプロトコル | function-calling, mcp, mcp-vs-function-calling-diff, a2a, multi-agent, subagent, agent-skills, structured-output | function-calling, mcp, a2a, multi-agent, subagent, agent-skills, structured-output | 5 | 未 |
| reading-ch3-05 | エージェントの権限管理と安全 | least-privilege, human-in-the-loop, sandbox, guardrail, prompt-injection, defense-in-depth, whitelist-defense | ai-agent, least-privilege, human-in-the-loop, sandbox, guardrail, prompt-injection | 6 | 済 |

### 4章 リスク予防・AI倫理・ガバナンス（5）

| ID | タイトル | 主な topicId | 主な termId | 節 | 状態 |
|---|---|---|---|---|---|
| reading-ch4-01 | 出力を確認する習慣 | fact-check, output-verification, verification-level, expert-confirmation, validity-review | fact-check, accountability | 5 | 未 |
| reading-ch4-02 | 個人情報と機密情報の守り方 | personal-info-def, sensitive-personal-info, anonymized-info, pseudonymized-info, trade-secret, nda, data-minimization-principle, cross-border-data-transfer-consideration | personal-info, sensitive-personal-info, anonymized-info, pseudonymized-info, trade-secret, nda, cross-border-data-transfer | 6 | 済 |
| reading-ch4-03 | 著作権と人の権利 | copyright-*, author-moral-rights, publicity-right, likeness-rights-neg, quote-vs-adaptation, defamation-risk | author-moral-rights, publicity-right, defamation-risk, c2pa | 5 | 未 |
| reading-ch4-04 | バイアスと公平性 | bias-*, fairness-example-scenario, filter-bubble, misinformation-echo-chamber, employment-impact | ai-bias, fairness, filter-bubble, misinformation-echo-chamber, elsi | 5 | 未 |
| reading-ch4-05 | 組織のルールとガバナンス | ai-governance-def, shadow-ai-*, ai-audit-trail-purpose, risk-based-approach, eu-ai-act, ai-act-japan, g7-hiroshima-process, sec-*（悪用・攻撃） | ai-governance, shadow-ai, ai-audit-trail, risk-based-approach, eu-ai-act, ai-act-japan, g7-hiroshima-process, mfa, social-engineering | 6 | 未 |

（4章の法令・国際動向は変わりやすいため、5本目は制度名と考え方の説明にとどめ、施行日・罰則額などの数値は書かない。）

### 5章 生成AIの実践と活用事例（4）

| ID | タイトル | 主な topicId | 主な termId | 節 | 状態 |
|---|---|---|---|---|---|
| reading-ch5-01 | プロンプトの組み立て方 | prompt-elements, role-setting, specificity-control, output-format-spec, delimiter-instruction-data, iterative-prompt-refinement | prompt, prompt-engineering, prompt-elements, role-setting, specificity-control, output-format-spec, iterative-refinement | 6 | 済 |
| reading-ch5-02 | 例示と段階的な思考 | zero-shot, few-shot-prompting, shot-count-difference, in-context-learning, chain-of-thought, cot-math-word-problem | zero-shot, few-shot, in-context-learning, chain-of-thought | 5 | 未 |
| reading-ch5-03 | 業務での活用の型 | business-doc, minutes-extraction, document-extraction-summary, translation, proofreading, data-cleaning, deep-research | business-doc, deep-research, multi-tool-automation, browser-automation | 5 | 未 |
| reading-ch5-04 | 導入の進め方と選び方 | tool-selection, adoption-approach-neg, cross-industry-success-points, regulated-industry-usage, customer-facing-industry | tool-selection, deep-research | 5 | 未 |

## 規模

- 全24章（既存の章まとめ5本は別）。第1弾8章（1/3）= 約47節・約7,000字。
- 残り16章 = 約81節・約14,000字（作業量の目安。執筆のほか、関連IDの照合とレビュー対応が必要）。

## 残りの作業

1. 上表「未」の16章を同じ形式で執筆（第2弾8章、第3弾8章に分けるとレビューしやすい）。
2. 各章で関連問題IDを `topicId` から付け、テストで存在確認。
3. 専門家レビュー（特に4章、3章の安全・権限、2章の仕組み説明）。確認後に `ai-draft` を外す。
4. 既存の章まとめ（`reading-ch1`〜`reading-ch5`）の `sourceRef` に残る旧い出典表記の見直し（本計画の範囲外。別途確認）。
