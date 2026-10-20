import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../screens/ai_news_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/mistake_note_screen.dart';
import '../screens/reading_screen.dart';
import '../screens/term_map_screen.dart';

/// 「学ぶ」タブの「道具」。間違いノート・ブックマーク・自分用メモ・用語集・読み物・用語マップ・今月のAI動向への入口。
/// 以前はホームの「今日やること」（間違いノート）と「道具」にあったもの。
/// 見出し名・並びは ukalab_g_kentei / ukalab_it_passport の「学ぶ」と同じ。
class LearnToolsSection extends StatelessWidget {
  const LearnToolsSection({super.key, required this.exam, required this.questions});

  final ExamConfig exam;
  final List<Question> questions;

  /// 一覧から開く問題の詳細。選択肢の記号は演習（A・B・C…）に合わせる。
  Widget _detailBuilder(BuildContext context, Question q) => QuestionDetailScreen(
        question: q,
        choiceLabels: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    return HomeSection(
      title: '道具',
      subtitle: '調べる・見返す',
      leading: const Icon(Icons.handyman_outlined),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeMenuTile(
              icon: Icons.edit_note_outlined,
              title: '間違いノート',
              subtitle: '間違えた問題を見返して、解き直せます。',
              onTap: () => openMistakeNote(context, exam: exam, questions: questions),
            ),
            const SizedBox(height: 8),
            // ブックマーク・自分用メモ（core のカード）。
            StudyNotesHomeCards(
                loadQuestions: () async => questions, detailBuilder: _detailBuilder),
            const SizedBox(height: 4),
            HomeMenuTile(
              icon: Icons.menu_book_outlined,
              title: '用語集',
              subtitle: '用語を検索して、覚えた用語にチェックを付けよう',
              onTap: () => _push(context, (_) => const GlossaryScreen()),
            ),
            const SizedBox(height: 8),
            HomeMenuTile(
              icon: Icons.auto_stories_outlined,
              title: '章ごとの解説読み物',
              subtitle: '公式の章立てに沿って、学習項目を体系的に読める',
              onTap: () => _push(context, (_) => const ReadingScreen()),
            ),
            const SizedBox(height: 8),
            HomeMenuTile(
              icon: Icons.hub_outlined,
              title: '用語マップ',
              subtitle: 'AIの歴史の系譜や、用語どうしのつながりを見る',
              onTap: () => _push(context, (_) => const TermMapScreen()),
            ),
            const SizedBox(height: 8),
            HomeMenuTile(
              icon: Icons.newspaper,
              title: '今月のAI動向',
              subtitle: '一次情報にもとづく最新動向を、自分の言葉での要約で',
              onTap: () => _push(context, (_) => const AiNewsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
