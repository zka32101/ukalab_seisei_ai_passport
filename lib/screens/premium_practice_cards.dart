import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_core/answer_feedback.dart' show WeakSummaryCard, canShowWeakSummary;
import 'package:ukalab_core/exam_date.dart';
import '../data/history_store.dart';
import 'learn_screen.dart';

/// ホームに出す、プレミアム機能の入口（弱点ドリル・試験直前モード）。
///
/// どちらも解答履歴から出題を組む。premium でなければ案内を出すだけで、画面には入らない
/// （うかラボ共通の線引き。[PremiumFeature]）。
class PremiumPracticeCards extends ConsumerWidget {
  const PremiumPracticeCards({
    super.key,
    required this.exam,
    required this.questions,
    this.clock = DateTime.now,
  });

  final ExamConfig exam;
  final List<Question> questions;

  /// 現在時刻の取得元（テストで固定する）。
  final DateTime Function() clock;

  bool _isPremium(WidgetRef ref) =>
      canUsePremiumFeature(
        PremiumFeature.weakDrill,
        isPremium: (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free)
            .hasPremium,
      );

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _open(BuildContext context, String title, List<Question> drill) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: LearnScreen(questions: drill, sessionSize: drill.length),
        ),
      ),
    );
  }

  void _weakDrill(BuildContext context, WidgetRef ref) {
    if (!_isPremium(ref)) {
      _toast(context, '弱点ドリルはプレミアムの機能です。設定から購入できます。');
      return;
    }
    final drill = buildWeakDrill(questions, ref.read(historyProvider), now: clock());
    if (drill.isEmpty) {
      _toast(context, 'まだ弱点がありません。「学ぶ」で演習すると、苦手な論点が見つかります。');
      return;
    }
    _open(context, '弱点ドリル', drill);
  }

  void _examEve(BuildContext context, WidgetRef ref) {
    if (!_isPremium(ref)) {
      _toast(context, '試験直前モードはプレミアムの機能です。設定から購入できます。');
      return;
    }
    final items = buildExamEveSet(questions, ref.read(historyProvider), now: clock());
    if (items.isEmpty) {
      _toast(context, '直前に見直す問題がまだありません。');
      return;
    }
    _open(context, '試験直前モード', [for (final i in items) i.question]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // タップ時に読むだけだと未購読で読み込み中のまま「無料」と判定されるため、ここで購読しておく。
    final isPremium =
        (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
    final eve = examEveStatus(effectiveExamDates(ref.watch(examDateProvider), exam.examDates), clock());
    return Column(
      children: [
        if (canShowWeakSummary(isPremium: isPremium)) ...[
          WeakSummaryCard(
            records: ref.watch(historyProvider),
            now: clock(),
            questions: questions,
            includeCalculation: false,
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.trending_down),
            title: const Text('弱点ドリル'),
            subtitle: const Text('間違えやすい論点を集中して解きます。（プレミアム）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _weakDrill(context, ref),
          ),
        ),
        if (eve != null && eve.active) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(eve.daysLeft == 0 ? '試験直前モード（今日が試験日）' : '試験直前モード（あと${eve.daysLeft}日）'),
              subtitle: const Text('直近の誤答・頻出・計算式を優先して見直します。（プレミアム）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _examEve(context, ref),
            ),
          ),
        ],
      ],
    );
  }
}
