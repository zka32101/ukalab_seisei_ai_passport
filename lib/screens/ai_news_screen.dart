import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ai_news_repository.dart';
import '../data/exam_repository.dart';
import 'learn_screen.dart';
import '../widgets/wrapped_app_bar.dart';

const _syllabusTagNames = {
  'ch1': '1章 AIの基礎と歴史',
  'ch2': '2章 生成AI',
  'ch3': '3章 AIエージェント',
  'ch4': '4章 リスク予防・AI倫理・ガバナンス',
  'ch5': '5章 実践と活用事例',
};

String _formatAsOf(DateTime d) => '${d.year}年${d.month}月時点';

/// 「今月のAI動向」（画期的な機能⑥、決定41）。一次情報のみを根拠にした
/// 要約（記事本文・見出しの転載はしない）を新しい順に表示する。
class AiNewsScreen extends ConsumerWidget {
  const AiNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(aiNewsItemsProvider);
    final examData = ref.watch(examDataProvider);

    return Scaffold(
      appBar: wrappedAppBar(context, '今月のAI動向'),
      body: news.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('読み込みに失敗しました。\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(message: 'まだ動向データがありません。');
          }

          final questions = examData.valueOrNull?.activeQuestions ?? const [];
          final questionsById = {for (final q in questions) q.qid: q};

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final relatedQuestion = item.relatedQuestionId == null
                  ? null
                  : questionsById[item.relatedQuestionId];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAsOf(item.asOfDate),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _syllabusTagNames[item.syllabusTag] ?? item.syllabusTag,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(item.summary, style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => launchUrl(
                              Uri.parse(item.sourceUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('一次情報を見る'),
                          ),
                          if (relatedQuestion != null)
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: wrappedAppBar(context, '関連問題'),
                                    body: LearnScreen(
                                      questions: questions,
                                      priorityQids: [relatedQuestion.qid],
                                    ),
                                  ),
                                ),
                              ),
                              child: const Text('関連問題を解く'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
