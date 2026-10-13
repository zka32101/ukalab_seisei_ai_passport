import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/core_features.dart';
import '../data/history_store.dart';
import '../data/mistake_notes.dart';
import '../data/oshi_recap.dart';
import '../data/review_schedule.dart';
import 'mistake_note_screen.dart';

/// ホーム「今日やること」の「今日の復習」。間違いノートから復習日程を同期し、期限の件数を出す。
/// 「やってみる」は既存の間違いノート画面を開く(出題画面は新しく作らない)。文言は ukalab_core。
class TodayReviewHomeCard extends ConsumerStatefulWidget {
  const TodayReviewHomeCard({
    super.key,
    required this.exam,
    required this.questions,
    this.clock = DateTime.now,
    this.noteStore,
    this.reviewStore,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final DateTime Function() clock;

  /// テスト用の差し替え。省略時は端末内の保存先。
  final MistakeNoteStore? noteStore;
  final ReviewSchedulerStore? reviewStore;

  @override
  ConsumerState<TodayReviewHomeCard> createState() =>
      _TodayReviewHomeCardState();
}

class _TodayReviewHomeCardState extends ConsumerState<TodayReviewHomeCard> {
  int _due = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 間違いノート(解答履歴を取り込んだ状態)から復習日程を同期する。何度呼んでも結果は同じ。
  /// 間違いノートの保存は画面側([MistakeNoteScreen])に任せ、ここでは書き換えない
  /// (「克服」のお祝いを先に消してしまわないため)。
  Future<void> _refresh() async {
    try {
      await ref.read(historyProvider.notifier).ready;
      if (!mounted) return;
      final notes = mistakeNoteEngine.update(
        await (widget.noteStore ?? mistakeNoteStore).read(),
        ref.read(historyProvider),
      );
      final store = widget.reviewStore ?? reviewSchedulerStore;
      final items = reviewSchedulerEngine.sync(await store.read(), notes);
      await store.write(items);
      if (!mounted) return;
      final available = {for (final q in widget.questions) q.qid};
      setState(
        () => _due = reviewSchedulerEngine.dueCount([
          for (final i in items)
            if (available.contains(i.qid)) i,
        ], widget.clock()),
      );
    } catch (_) {
      // 復習日程は派生データ。読めなければ件数 0 の穏やかな表示のまま。
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyProvider, (previous, next) => _refresh());
    return TodayReviewCard(
      dueCount: _due,
      onStart: () => openMistakeNote(
        context,
        exam: widget.exam,
        questions: widget.questions,
      ),
    );
  }
}

/// ホーム「記録」の模擬試験の結果分析。直近の解答履歴を科目ごとに見て、
/// 「今日はここを少しだけ」を出す。分野名は試験設定の科目名。文言は ukalab_core。
class MockExamAnalysisHomeCard extends ConsumerWidget {
  const MockExamAnalysisHomeCard({super.key, required this.exam});

  final ExamConfig exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = const MockExamAnalysisEngine().analyze(
      mockExamAnswersFrom(ref.watch(historyProvider)),
    );
    return MockExamAnalysisCard(
      analysis: analysis,
      topicLabel: (id) => exam.subject(id)?.name ?? id,
    );
  }
}

/// ホーム「記録」の推しの成長演出。累計の回答数・学習日数で推しの反応が変わり、
/// 節目(10/50/100問・7/30日など)に着いたら一度だけ祝う。
///
/// 祝福はこのタブが見えているときだけ(ほかのタブで解いている最中に出さない)。
/// 久しぶりに開いて複数の節目を迎えても、祝福は最も大きい1件だけ。
class OshiGrowthHomeCard extends ConsumerStatefulWidget {
  const OshiGrowthHomeCard({super.key, this.store});

  /// テスト用の差し替え。省略時は端末内の保存先。
  final OshiGrowthStore? store;

  @override
  ConsumerState<OshiGrowthHomeCard> createState() => _OshiGrowthHomeCardState();
}

class _OshiGrowthHomeCardState extends ConsumerState<OshiGrowthHomeCard> {
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブが見えるようになったとき(起動直後を含む)に確認する。
    if (TickerMode.of(context)) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      await ref.read(historyProvider.notifier).ready;
      if (!mounted) return;
      final svc = OshiGrowthService(
        store: widget.store ?? SharedPreferencesOshiGrowthStore(kExamId),
      );
      await svc.load();
      final milestone = await svc.checkHeadline(
        oshiGrowthProgressFor(ref.read(historyProvider)),
      );
      if (milestone == null || !mounted || !TickerMode.of(context)) return;
      await showOshiGrowthDialog(context, milestone: milestone);
    } catch (_) {
      // 保存できなかったときは記録されず、次回また祝える。
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => OshiGrowthBubble(
    progress: oshiGrowthProgressFor(ref.watch(historyProvider)),
  );
}
