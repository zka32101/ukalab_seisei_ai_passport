import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/mistake_notes.dart';
import '../data/oshi_recap.dart';
import 'learn_screen.dart';

/// 間違いノート。ukalab_core の [MistakeNoteView] に、このアプリの履歴・保存先・出題画面をつなぐ。
/// 無料で使える(core の [PremiumFeature] に該当機能がないため)。
///
/// 開くたびに解答履歴から取り込み(同じ履歴を何度渡しても結果は同じ)、「解き直す」は
/// 既存の演習画面([LearnScreen])を、その1問だけで開く。戻ったときにもう一度取り込み、
/// 新しく克服した問題があれば祝う。
class MistakeNoteScreen extends ConsumerStatefulWidget {
  const MistakeNoteScreen({
    super.key,
    required this.exam,
    required this.questions,
    this.store,
  });

  final ExamConfig exam;
  final List<Question> questions;

  /// テスト用の差し替え。省略時は端末内の保存先。
  final MistakeNoteStore? store;

  @override
  ConsumerState<MistakeNoteScreen> createState() => _MistakeNoteScreenState();
}

class _MistakeNoteScreenState extends ConsumerState<MistakeNoteScreen> {
  List<MistakeNoteEntry>? _entries;
  Set<String> _celebrate = const {};

  MistakeNoteStore get _store => widget.store ?? mistakeNoteStore;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// 保存済みのノートに、解答履歴を取り込んで保存する。
  Future<void> _sync() async {
    // 履歴の読み込み完了を待つ(読み込み前に空の履歴で取り込まない)。
    await ref.read(historyProvider.notifier).ready;
    if (!mounted) return;
    final before = await _store.read();
    if (!mounted) return;
    final after = mistakeNoteEngine.update(before, ref.read(historyProvider));
    await _store.write(after);
    if (!mounted) return;
    setState(() {
      _entries = after;
      _celebrate = mistakeNoteEngine.newlyOvercome(before, after).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final byQid = {for (final q in widget.questions) q.qid: q};
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('間違いノート')),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : MistakeNoteView(
              // 出題データに無くなった問題は出せないので除く。
              entries: [for (final e in entries) if (byQid.containsKey(e.qid)) e],
              celebrateQids: _celebrate,
              topicLabel: topicLabelFor(
                  widget.questions, (id) => widget.exam.subject(id)?.name),
              questionBuilder: (context, entry) => Text(byQid[entry.qid]!.prompt),
              onRetry: (entry) async {
                final q = byQid[entry.qid];
                if (q == null) return;
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('解き直す')),
                    body: LearnScreen(questions: [q], sessionSize: 1),
                  ),
                ));
                if (mounted) await _sync();
              },
            ),
    );
  }
}

/// 間違いノートを開く入口(設定・ホームで共通)。
void openMistakeNote(
  BuildContext context, {
  required ExamConfig exam,
  required List<Question> questions,
}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MistakeNoteScreen(exam: exam, questions: questions),
    ));
