import 'package:ukalab_core/ukalab_core.dart';

/// 推しの一言・週間ふりかえりに渡す入力を、アプリの既存データ(解答履歴・試験日)から作る。
/// 文言・判定は ukalab_core 側。ここは入力を作るだけ(個人情報・問題IDは入れない)。

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 解答履歴から、今日(または昨日)まで続いている連続学習日数。途切れていれば 0。
int currentStreakDays(List<ProgressRecord> records, DateTime now) {
  final days = {for (final r in records) _day(r.at)};
  var cursor = _day(now);
  // 今日まだ解いていなくても、昨日までの連続は続いているものとして数える。
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(cursor)) {
    n++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return n;
}

/// 推しの一言の状況。[now] は「今日」の基準(テストで固定できる)。
OshiMessageContext oshiMessageContextFor({
  required List<ProgressRecord> records,
  required DateTime now,
  DateTime? examDate,
}) {
  final today = _day(now);

  DateTime? lastStudy;
  var todayAnswered = 0;
  var todayCorrect = 0;
  for (final r in records) {
    final d = _day(r.at);
    if (lastStudy == null || d.isAfter(lastStudy)) lastStudy = d;
    if (d == today) {
      todayAnswered++;
      if (r.correct) todayCorrect++;
    }
  }
  final since = lastStudy == null ? null : today.difference(lastStudy).inDays;

  int? examDaysLeft;
  if (examDate != null) {
    final left = _day(examDate).difference(today).inDays;
    if (left >= 0) examDaysLeft = left;
  }

  return OshiMessageContext(
    daysSinceLastStudy: since == null || since < 0 ? null : since,
    // 連続日数は今日か昨日まで続いているときだけ数える(途切れた古い値で褒めない)。
    streakDays: currentStreakDays(records, now),
    todayAnswered: todayAnswered,
    todayCorrectRate: todayAnswered == 0 ? null : todayCorrect / todayAnswered,
    examDaysLeft: examDaysLeft,
    hasWeakTopics: computeWeakTopics(records, now: now, byChapter: true).isNotEmpty,
  );
}

/// 週間ふりかえり(今週。月曜始まり)。メダルは獲得日を持たないため数えない(0)。
WeeklyRecap weeklyRecapFor({
  required List<ProgressRecord> records,
  required DateTime now,
}) =>
    const WeeklyRecapEngine(weekStartsOn: DateTime.monday)
        .build(weeklyRecapDaysFromRecords(records), weekOf: now);

/// 分野(topicId)の表示名。topicId は章のslugなので、その問題の科目名で表す。
/// 見つからなければ ID をそのまま返す。
String Function(String topicId) topicLabelFor(
  List<Question> questions,
  String? Function(String subjectId) subjectName,
) {
  final byTopic = <String, String>{};
  for (final q in questions) {
    final name = subjectName(q.subjectId);
    if (name != null) byTopic.putIfAbsent(q.topicId, () => name);
  }
  return (id) => byTopic[id] ?? id;
}

/// 弱点カード用の論点の表示名。論点ID(slug)は画面に出さない。
/// 科目IDならその科目名、論点IDならその論点の最初の問題文の先頭([maxChars]字)。
/// どちらも引けないときは汎用の「この論点」(IDは出さない)。
String Function(String topicId) weakTopicLabelFor(
  List<Question> questions,
  String? Function(String subjectId) subjectName, {
  int maxChars = 24,
}) {
  final byTopic = <String, String>{};
  for (final q in questions) {
    if (byTopic.containsKey(q.topicId)) continue;
    final flat = q.displayPrompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) continue;
    final head = flat.runes.length > maxChars
        ? '${String.fromCharCodes(flat.runes.take(maxChars))}…'
        : flat;
    byTopic[q.topicId] = head;
  }
  return (id) => subjectName(id) ?? byTopic[id] ?? 'この論点';
}

/// 推しの成長演出に渡す累計。回答数と学習日数(連続ではなく合計)を解答履歴から数える。
/// 履歴は端末内に直近 [historyMaxRecords] 件まで保存されるため、それより古い分は含まれない。
OshiGrowthProgress oshiGrowthProgressFor(List<ProgressRecord> records) => OshiGrowthProgress(
      totalAnswered: records.length,
      studyDays: {for (final r in records) _day(r.at)}.length,
    );

/// 模擬試験の結果分析に渡す回答。直近 [limit] 件の解答履歴を、科目(subjectId)単位で渡す。
List<MockExamAnswer> mockExamAnswersFrom(List<ProgressRecord> records, {int limit = 200}) {
  final recent = records.length > limit ? records.sublist(records.length - limit) : records;
  return [for (final r in recent) MockExamAnswer(topicId: r.subjectId, correct: r.correct)];
}
