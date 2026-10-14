import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'ai_news_screen.dart';
import 'boundary_screen.dart';
import 'core_v069_cards.dart';
import 'confusion_matrix_screen.dart';
import 'failure_gallery_screen.dart';
import 'predict_run_screen.dart';
import 'oshi_home_cards.dart';
import 'exam_prep_entry.dart';
import 'mistake_note_screen.dart';
import 'nagara_entry.dart';
import 'premium_practice_cards.dart';
import 'route_planner_screen.dart';
import 'teach_mascot_screen.dart';
import 'glossary_screen.dart';
import 'reading_screen.dart';
import 'term_map_screen.dart';

/// ホームの分類（折りたたみ・見出し単位）。
enum _HomeGroup { today, tools, lab }

class _ExperienceEntry {
  const _ExperienceEntry({
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final _HomeGroup group;
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final _experienceEntries = [
  _ExperienceEntry(
    group: _HomeGroup.tools,
    icon: Icons.newspaper,
    title: '今月のAI動向',
    subtitle: '一次情報にもとづく最新動向を、自分の言葉での要約で',
    builder: (_) => const AiNewsScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.lab,
    icon: Icons.auto_awesome,
    title: '推しの答案を添削',
    subtitle: 'よくある誤解を見つけて、正しい答えに差し替えよう',
    builder: (_) => const TeachMascotScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.lab,
    icon: Icons.show_chart,
    title: '学習の失敗図鑑',
    subtitle: '学習曲線から症状を見抜き、正しい対策を選ぼう',
    builder: (_) => const FailureGalleryScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.tools,
    icon: Icons.menu_book_outlined,
    title: '用語集',
    subtitle: '用語を検索して、覚えた用語にチェックを付けよう',
    builder: (_) => const GlossaryScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.tools,
    icon: Icons.auto_stories_outlined,
    title: '章ごとの解説読み物',
    subtitle: '公式の章立てに沿って、学習項目を体系的に読める',
    builder: (_) => const ReadingScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.tools,
    icon: Icons.hub_outlined,
    title: '用語マップ',
    subtitle: 'AIの歴史の系譜や、用語どうしのつながりを見る',
    builder: (_) => const TermMapScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.lab,
    icon: Icons.tune,
    title: '境界線スライダー',
    subtitle: '条件を切り替えて、判定が変わる境目を体験しよう',
    builder: (_) => const BoundaryScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.lab,
    icon: Icons.grid_on,
    title: '評価指標ラボ',
    subtitle: '混同行列を動かして、正解率・適合率・再現率を見てみよう',
    builder: (_) => const ConfusionMatrixScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.lab,
    icon: Icons.science_outlined,
    title: '温度の実験室',
    subtitle: '先に答えを予測してから、計算結果とのズレを確かめよう',
    builder: (_) => const PredictRunScreen(),
  ),
  _ExperienceEntry(
    group: _HomeGroup.today,
    icon: Icons.checklist,
    title: '今日やる3つ',
    subtitle: '弱点と配点から、今日取り組むべき科目を3つ提案',
    builder: (_) => const RoutePlannerScreen(),
  ),
];

/// 「ホーム」タブ。分類ごとの見出し（HomeSection）で並べる。推しカードは後続で追加。
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

  List<_ExperienceEntry> _entries(_HomeGroup g) =>
      _experienceEntries.where((e) => e.group == g).toList();

  Widget _tile(BuildContext context, _ExperienceEntry e) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: HomeMenuTile(
          icon: e.icon,
          title: e.title,
          subtitle: e.subtitle,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: e.builder)),
        ),
      );

  HomeMenuItem _item(BuildContext context, _ExperienceEntry e) => HomeMenuItem(
        icon: e.icon,
        title: e.title,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: e.builder)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = _entries(_HomeGroup.tools);
    final toolsTop = tools.where((e) => e.title == '今月のAI動向').toList();
    final toolsRest = tools.where((e) => e.title != '今月のAI動向').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('うかラボ 生成AIパスポート', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '生成AIパスポート試験対策（GUGA・一般社団法人生成AI活用普及協会とは無関係の非公式アプリ）',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OshiMessageCard(exam: exam),
          _PersistedHomeSection(
            id: 'today',
            title: '今日やること',
            leading: const Icon(Icons.today_outlined),
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DailyMissionCard(),
                const StudyReminderCard(),
                TodayReviewHomeCard(exam: exam, questions: questions),
                const SizedBox(height: 8),
                NagaraEntryCard(questions: questions),
                const SizedBox(height: 8),
                PremiumPracticeCards(exam: exam, questions: questions),
                for (final e in _entries(_HomeGroup.today)) _tile(context, e),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: HomeMenuTile(
                    icon: Icons.edit_note_outlined,
                    title: '間違いノート',
                    subtitle: '間違えた問題を見返して、解き直せます。',
                    onTap: () => openMistakeNote(context, exam: exam, questions: questions),
                  ),
                ),
              ],
            ),
          ),
          _PersistedHomeSection(
            id: 'record',
            title: '記録',
            leading: const Icon(Icons.insights_outlined),
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WeeklyRecapSection(exam: exam, questions: questions),
                const SizedBox(height: 8),
                MockExamAnalysisHomeCard(exam: exam),
                const SizedBox(height: 8),
                const OshiGrowthHomeCard(),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
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
              ],
            ),
          ),
          _PersistedHomeSection(
            id: 'exam',
            title: '試験に向けて',
            leading: const Icon(Icons.flag_outlined),
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExamCountdownEntry(exam: exam),
                const SizedBox(height: 4),
                ExamPrepEntryCard(exam: exam, questions: questions),
              ],
            ),
          ),
          _PersistedHomeSection(
            id: 'tools',
            title: '道具',
            subtitle: '調べる・読む・書きとめる',
            leading: const Icon(Icons.handyman_outlined),
            initiallyExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudyNotesHomeCards(loadQuestions: () async => questions),
                const SizedBox(height: 8),
                HomeMenuGrid(items: [
                  for (final e in toolsRest) _item(context, e),
                  for (final e in toolsTop) _item(context, e),
                ]),
              ],
            ),
          ),
          _PersistedHomeSection(
            id: 'lab',
            title: '体験ラボ',
            subtitle: '動かして確かめる',
            leading: const Icon(Icons.science_outlined),
            initiallyExpanded: false,
            child: HomeMenuGrid(items: [
              for (final e in _entries(_HomeGroup.lab)) _item(context, e),
            ]),
          ),
        ],
      ),
    );
  }
}

/// 折りたたみ状態を SharedPreferences（`ukalab_seisei_home_section_<id>`）に保存する HomeSection。
class _PersistedHomeSection extends StatefulWidget {
  const _PersistedHomeSection({
    required this.id,
    required this.title,
    required this.child,
    required this.initiallyExpanded,
    this.subtitle,
    this.leading,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_PersistedHomeSection> createState() => _PersistedHomeSectionState();
}

class _PersistedHomeSectionState extends State<_PersistedHomeSection> {
  late final ValueNotifier<bool> _expanded = ValueNotifier(widget.initiallyExpanded);
  String get _key => 'ukalab_seisei_home_section_${widget.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_key);
      if (v != null && mounted) _expanded.value = v;
    } catch (_) {
      // 保存できなくても既定の開閉で表示する。
    }
  }

  Future<void> _save(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeSection(
        title: widget.title,
        subtitle: widget.subtitle,
        leading: widget.leading,
        collapsible: true,
        expandedListenable: _expanded,
        onExpandedChanged: _save,
        child: widget.child,
      );
}
