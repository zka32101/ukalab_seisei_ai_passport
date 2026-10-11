import 'package:flutter/material.dart';
import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'ai_news_screen.dart';
import 'boundary_screen.dart';
import 'confusion_matrix_screen.dart';
import 'failure_gallery_screen.dart';
import 'predict_run_screen.dart';
import 'premium_practice_cards.dart';
import 'route_planner_screen.dart';
import 'teach_mascot_screen.dart';
import 'glossary_screen.dart';
import 'term_map_screen.dart';

class _ExperienceEntry {
  const _ExperienceEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final _experienceEntries = [
  _ExperienceEntry(
    icon: Icons.newspaper,
    title: '今月のAI動向',
    subtitle: '一次情報にもとづく最新動向を、自分の言葉での要約で',
    builder: (_) => const AiNewsScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.auto_awesome,
    title: '推しの答案を添削',
    subtitle: 'よくある誤解を見つけて、正しい答えに差し替えよう',
    builder: (_) => const TeachMascotScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.show_chart,
    title: '学習の失敗図鑑',
    subtitle: '学習曲線から症状を見抜き、正しい対策を選ぼう',
    builder: (_) => const FailureGalleryScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.menu_book_outlined,
    title: '用語集',
    subtitle: '用語を検索して、覚えた用語にチェックを付けよう',
    builder: (_) => const GlossaryScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.hub_outlined,
    title: '用語マップ',
    subtitle: 'AIの歴史の系譜や、用語どうしのつながりを見る',
    builder: (_) => const TermMapScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.tune,
    title: '境界線スライダー',
    subtitle: '条件を切り替えて、判定が変わる境目を体験しよう',
    builder: (_) => const BoundaryScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.grid_on,
    title: '評価指標ラボ',
    subtitle: '混同行列を動かして、正解率・適合率・再現率を見てみよう',
    builder: (_) => const ConfusionMatrixScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.science_outlined,
    title: '温度の実験室',
    subtitle: '先に答えを予測してから、計算結果とのズレを確かめよう',
    builder: (_) => const PredictRunScreen(),
  ),
  _ExperienceEntry(
    icon: Icons.checklist,
    title: '今日やる3つ',
    subtitle: '弱点と配点から、今日取り組むべき科目を3つ提案',
    builder: (_) => const RoutePlannerScreen(),
  ),
];

/// 「ホーム」タブ。推し・コインは後続で追加。
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.exam,
    required this.questionCount,
    this.questions = const [],
  });

  final ExamConfig exam;
  final int questionCount;

  /// 弱点ドリル・試験直前モードの出題元（解答履歴と突き合わせる）。
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('うかラボ 生成AIパスポート', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '生成AIパスポート試験対策（GUGA・一般社団法人生成AI活用普及協会とは無関係の非公式アプリ）',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('収録問題数', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text('$questionCount問', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    '「学ぶ」タブで演習、「模擬」タブで本番形式の採点ができます。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const DailyMissionCard(),
          const StudyReminderCard(),
          const SizedBox(height: 8),
          PremiumPracticeCards(exam: exam, questions: questions),
          const SizedBox(height: 8),
          StudyNotesHomeCards(loadQuestions: () async => questions),
          for (final entry in _experienceEntries) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: entry.builder),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
