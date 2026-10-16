import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'feature_flags.dart';

/// 生成AIパスポートの試験定義と問題データを assets から読み込む。
class ExamData {
  const ExamData({
    required this.exam,
    required this.questions,
    this.newQuestionTypesEnabled = kNewQuestionTypesEnabled,
  });

  final ExamConfig exam;
  final List<Question> questions;

  /// 新しい問題タイプを出題に含めるか（既定は [kNewQuestionTypesEnabled]。テストで切り替える）。
  final bool newQuestionTypesEnabled;

  /// 出題に使える問題。無効（disabled）と、フラグが false のときの新タイプを除く。
  List<Question> get activeQuestions => selectableQuestions(
        questions.where((q) => !q.disabled),
        newTypesEnabled: newQuestionTypesEnabled,
      );
}

Future<ExamData> loadExamData() async {
  final examText =
      await rootBundle.loadString('content/exam/seisei_ai_passport.json');
  final exam =
      ExamConfig.fromJson(jsonDecode(examText) as Map<String, dynamic>);

  final jsonl = await rootBundle.loadString('content/exam/questions.jsonl');
  final parsed = parseQuestionsJsonl(jsonl);
  final issues = [
    ...parsed.issues,
    ...validateQuestions(parsed.questions, exam: exam),
  ];
  if (issues.isNotEmpty) {
    throw StateError('問題データに不備があります: ${issues.first}');
  }
  return ExamData(exam: exam, questions: parsed.questions);
}

final examDataProvider = FutureProvider<ExamData>((ref) => loadExamData());
