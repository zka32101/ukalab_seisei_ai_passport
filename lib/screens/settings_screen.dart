import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/achievements.dart' show AchievementsView, dailyGoalAchievementCategoryLabels;
import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromoSection;
import 'package:ukalab_core/daily_goal.dart' show DailyGoalSetting;
import 'package:ukalab_core/reminder.dart' show ReminderSettingsSection;
import 'package:ukalab_core/ui.dart' show DataManagementSection;
import 'package:ukalab_core/ukalab_core.dart' show Question, historyCsv;

import 'package:ukalab_core/exam_date.dart';
import '../data/data_parts.dart';
import '../data/history_store.dart';

/// 「設定」タブ。課金・広告・通知の設定は後続。
/// インストールされたアプリの版（pubspec の version）。取得できないときは空にして画面は落とさない。
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return '';
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.questions = const []});

  /// 履歴CSVの分野集計で、記録に章が無い旧データを補うために使う。
  final List<Question> questions;

  Future<void> _copyHistory(BuildContext context, WidgetRef ref) async {
    final records = ref.read(historyProvider);
    final message = records.isEmpty ? 'まだ学習履歴がありません。' : '学習履歴をコピーしました。';
    if (records.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: historyCsv(records, questions)));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handsFree = ref.watch(handsFreeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PurchaseSection(),
        const Divider(height: 32),
        SwitchListTile(
          title: const Text('ながら学習モード'),
          subtitle: const Text('大きな選択肢ボタンで、問題を読み上げます。'),
          value: handsFree.enabled,
          onChanged: (v) => ref.read(handsFreeProvider.notifier).setEnabled(v),
        ),
        if (handsFree.enabled)
          SwitchListTile(
            title: const Text('問題を読み上げる'),
            value: handsFree.speakQuestion,
            onChanged: (v) => ref.read(handsFreeProvider.notifier).setSpeakQuestion(v),
          ),
        ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
        ListTile(
          title: const Text('学習履歴をコピー（CSV）'),
          subtitle: const Text('日ごと・分野ごとの解答数と正答率。個人情報は含みません。'),
          onTap: () => _copyHistory(context, ref),
        ),
        const Divider(height: 32),
        const DailyGoalSetting(),
        const Divider(height: 32),
        const ReminderSettingsSection(),
        const Divider(height: 32),
        DataManagementSection(
          parts: seiseiDataParts,
          description: '解答履歴・間隔反復の記録・自分用メモは、試験日・ブックマークを除いて、'
              '書き出し・読み込み・リセットができます。',
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('実績'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AchievementsView(categoryLabels: dailyGoalAchievementCategoryLabels),
            ),
          ),
        ),
        const Divider(height: 32),
        // 掲載リストが空なら何も表示されない。うかラボは大人向けなので保護者ゲートは不要。
        const UkalabCrossPromoSection(
          currentAppId: 'com.yourwish.ukalab.seisei_ai_passport',
        ),
        const ListTile(
          title: Text('このアプリについて'),
          subtitle: Text(
            '「うかラボ 生成AIパスポート」は、GUGA（一般社団法人生成AI活用普及協会）とは'
            '無関係に開発・運営する非公式の学習アプリです。問題はすべて独自に作成しています。',
          ),
        ),
        const Divider(height: 1),
        ListTile(
          title: const Text('バージョン'),
          // 実際にインストールされた版（pubspec の version）を読む。
          subtitle: Text(ref.watch(appVersionProvider).valueOrNull ?? ''),
        ),
      ],
    );
  }
}
