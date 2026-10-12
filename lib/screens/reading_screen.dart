import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/ui.dart';

import '../data/exam_repository.dart';
import '../data/reading_repository.dart';
import '../data/term_repository.dart';
import 'learn_screen.dart';

/// 章ごとの解説読み物（教科書的なまとめページ）の一覧。
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  bool _isPremium(WidgetRef ref) => canUsePremiumFeature(
        PremiumFeature.readingReadAloud,
        isPremium: (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free)
            .hasPremium,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(chapterReadingsProvider);
    final terms = ref.watch(termsProvider);
    final examData = ref.watch(examDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('章ごとの解説読み物')),
      body: readings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('読み込みに失敗しました。\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(message: '解説読み物のデータがまだありません。');
          }

          final termsList = terms.valueOrNull ?? const [];
          final termsById = {
            for (final t in termsList) t.termId: t,
          };
          final termReferences = [
            for (final t in termsList) TermReference(termId: t.termId, matchText: t.term),
          ];
          final questions = examData.valueOrNull?.activeQuestions ?? const [];
          final questionsById = {for (final q in questions) q.qid: q};

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(r.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(r.title)),
                        body: ChapterReadingWidget(
                          title: r.title,
                          sections: [
                            for (final s in r.sections)
                              ReadingSectionView(heading: s.heading, body: s.body),
                          ],
                          relatedTerms: [
                            for (final id in r.relatedTermIds)
                              if (termsById[id] != null)
                                RelatedTermRef(termId: id, label: termsById[id]!.term),
                          ],
                          relatedQuestions: [
                            for (final id in r.relatedQuestionIds)
                              if (questionsById[id] != null)
                                RelatedQuestionRef(
                                  questionId: id,
                                  label: questionsById[id]!.prompt,
                                ),
                          ],
                          bodyTermReferences: termReferences,
                          onReadAloud: !_isPremium(ref)
                              ? null
                              : () {
                                  final text =
                                      r.sections.map((s) => '${s.heading}。${s.body}').join('');
                                  ref.read(handsFreeSpeakerProvider).speakNow(text);
                                },
                          onRelatedTermTap: (termId) {
                            final term = termsById[termId];
                            if (term == null) return;
                            showTermCard(
                              context,
                              term: term.term,
                              headline: term.headline,
                              definition: term.definition,
                              analogy: term.analogy,
                              commonMistake: term.commonMistake,
                            );
                          },
                          onRelatedQuestionTap: (qid) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(title: const Text('関連問題')),
                                  body: LearnScreen(
                                    questions: questions,
                                    priorityQids: [qid],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
