import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';

import '../data/exam_repository.dart';
import '../data/term_repository.dart';
import 'learn_screen.dart';

/// 時代区分IDの表示順（先頭が古い時代）。`content/exam/README.md`の
/// 「用語マップ・AI系譜図向け時代区分」に合わせたアプリ側（UI層）の定義。
const _eraOrder = {
  'era-first-boom': '第一次AIブーム・冬',
  'era-second-boom': '第二次AIブーム',
  'era-ml-foundations': '機械学習の確立期',
  'era-deep-learning': '深層学習・第三次AIブーム',
  'era-genai': '生成AI時代',
  'era-agentic-ai': 'AIエージェント時代',
};

/// 「用語マップ」（画期的な機能⑤）。AIの歴史は時代区分のタイムライン、
/// それ以外は関連でつながる地図で表示し、タップで用語カードを開く。
class TermMapScreen extends ConsumerWidget {
  const TermMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(termsProvider);
    final examData = ref.watch(examDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('用語マップ')),
      body: terms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('読み込みに失敗しました。\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(message: 'まだ用語がありません。');
          }

          final byId = {for (final t in list) t.termId: t};
          final questions = examData.valueOrNull?.activeQuestions ?? const [];
          final questionsById = {for (final q in questions) q.qid: q};

          void openTerm(String termId) {
            final t = byId[termId];
            if (t == null) return;
            showTermCard(
              context,
              term: t.term,
              headline: t.headline,
              definition: t.definition,
              analogy: t.analogy,
              commonMistake: t.commonMistake,
              relatedTerms: [
                for (final id in t.relatedTermIds)
                  if (byId[id] != null)
                    RelatedTermRef(termId: id, label: byId[id]!.term),
              ],
              relatedQuestions: [
                for (final id in t.relatedQuestionIds)
                  if (questionsById[id] != null)
                    RelatedQuestionRef(
                      questionId: id,
                      label: questionsById[id]!.prompt,
                    ),
              ],
              onRelatedTermTap: openTerm,
              onRelatedQuestionTap: (qid) {
                final q = questionsById[qid];
                if (q == null) return;
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('関連問題')),
                      body: LearnScreen(
                        questions: questions,
                        priorityQids: [qid],
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TermMapWidget(
              nodes: [
                for (final t in list)
                  TermMapNodeSpec(
                    termId: t.termId,
                    label: t.term,
                    era: t.era,
                    relatedTermIds: t.relatedTermIds,
                  ),
              ],
              eraOrder: _eraOrder,
              onNodeTap: openTerm,
            ),
          );
        },
      ),
    );
  }
}
