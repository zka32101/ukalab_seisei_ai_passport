import 'package:ukalab_core/ukalab_core.dart';

/// 新しい問題タイプ（○×=trueFalse / 空欄補充=cloze / 説明から用語=reverseLookup。
/// ukalab_core v0.75.0〜）を出題に含めるか。
///
/// **false（既定）**: 出題データに含まれていても、演習・復習・間違いノート・
/// 模擬試験・検索・しおり・読み物の関連問題のどこにも出さない
/// （[ExamData.activeQuestions] で全プールから除く）。ユーザーに見える変化はない。
/// **true**: 演習・復習・間違いノートの解き直しなどに含める。解答は
/// `LearnScreen` が core の 3 画面で受け、履歴・進捗・間違いノート・復習予定に記録する。
///
/// フラグの値に関わらず次は変わらない:
/// - 模擬試験: 新タイプは出さない（[kMockExamAllowedTypes] = core 既定の4タイプ）
/// - ながらセッション（音声）: 新タイプは出さない（選択式前提の画面）
///
/// コンパイル時定数。ビルドごとに変える（テストでは各関数の `newTypesEnabled` 引数で切り替える）。
const bool kNewQuestionTypesEnabled = false;

/// 模擬試験に出すタイプ。core の既定（従来の4タイプ）のまま。
const Set<QuestionType> kMockExamAllowedTypes = defaultMockExamTypes;

/// ○×・空欄補充・説明から用語のいずれか。
bool isNewQuestionType(Question q) =>
    q.type == QuestionType.trueFalse ||
    q.type == QuestionType.cloze ||
    q.type == QuestionType.reverseLookup;

/// フラグに従って出題プールを絞る。[newTypesEnabled] が false なら新タイプを除く。順序は保つ。
List<Question> selectableQuestions(
  Iterable<Question> questions, {
  bool newTypesEnabled = kNewQuestionTypesEnabled,
}) =>
    [
      for (final q in questions)
        if (newTypesEnabled || !isNewQuestionType(q)) q,
    ];

/// 選択式前提の画面（ながらセッション）用。フラグに関わらず新タイプを除く。
List<Question> withoutNewTypes(Iterable<Question> questions) =>
    selectableQuestions(questions, newTypesEnabled: false);

/// 模擬試験用。[kMockExamAllowedTypes] 以外のタイプを除く。
List<Question> mockExamEligible(Iterable<Question> questions) => [
      for (final q in questions)
        if (kMockExamAllowedTypes.contains(q.type)) q,
    ];
