import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/glossary.dart';

import '../data/exam_repository.dart';
import '../data/term_repository.dart';
import '../widgets/wrapped_app_bar.dart';

/// 「用語集」。検索・分野での絞り込み・「覚えた」チェックは core の [GlossaryListView]。
class GlossaryScreen extends ConsumerStatefulWidget {
  const GlossaryScreen({super.key});

  @override
  ConsumerState<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends ConsumerState<GlossaryScreen> {
  final _store = LearnedTermsStore('seisei_ai_passport');

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(termsProvider);
    final exam = ref.watch(examDataProvider).valueOrNull?.exam;
    return Scaffold(
      appBar: wrappedAppBar(context, '用語集'),
      body: terms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorState(message: '読み込みに失敗しました: $e'),
        data: (list) => GlossaryListView(
          terms: list,
          store: _store,
          subjects: {if (exam != null) for (final s in exam.subjects) s.subjectId: s.name},
        ),
      ),
    );
  }
}
