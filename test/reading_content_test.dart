import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

// 章ごとの解説読み物（content/exam/reading.jsonl）のデータ検証。
// 画面は起動せず、ファイルを直接読む。

String _read(String path) => File(path).readAsStringSync();

/// 拡充分（1章に複数レコード）の readingId 形式。例: reading-ch2-03
final _expandedId = RegExp(r'^reading-ch[1-5]-\d{2}$');

const _forbidden = ['公式', '本試験相当', '合格保証', '試験に出る'];

void main() {
  late List<ChapterReading> readings;
  late ExamConfig exam;
  late List<String> termIds;
  late List<String> questionIds;

  setUpAll(() {
    final parsed = parseChapterReadingsJsonl(_read('content/exam/reading.jsonl'));
    expect(parsed.issues, isEmpty);
    readings = parsed.items;
    exam = ExamConfig.fromJson(
        jsonDecode(_read('content/exam/seisei_ai_passport.json')) as Map<String, dynamic>);
    termIds = parseTermsJsonl(_read('content/exam/terms.jsonl')).terms.map((t) => t.termId).toList();
    questionIds =
        parseQuestionsJsonl(_read('content/exam/questions.jsonl')).questions.map((q) => q.qid).toList();
  });

  test('読み物が読み込め、core の検証（重複・章・参照ID）を通る', () {
    expect(readings, isNotEmpty);
    final issues =
        validateChapterReadings(readings, exam: exam, termIds: termIds, questionIds: questionIds);
    expect(issues, isEmpty, reason: issues.map((i) => '${i.qid} ${i.code} ${i.message}').join('\n'));
  });

  test('relatedTermIds / relatedQuestionIds は実在するIDだけで、重複もない', () {
    for (final r in readings) {
      for (final id in r.relatedTermIds) {
        expect(termIds, contains(id), reason: '${r.readingId}: 未定義の用語 $id');
      }
      for (final id in r.relatedQuestionIds) {
        expect(questionIds, contains(id), reason: '${r.readingId}: 未定義の問題 $id');
      }
      expect(r.relatedTermIds.toSet().length, r.relatedTermIds.length,
          reason: '${r.readingId}: 用語IDが重複');
      expect(r.relatedQuestionIds.toSet().length, r.relatedQuestionIds.length,
          reason: '${r.readingId}: 問題IDが重複');
    }
  });

  test('全レコードの source は original', () {
    for (final r in readings) {
      expect(r.source, QuestionSource.original, reason: r.readingId);
    }
  });

  test('拡充分は ai-draft の印があり、4〜6節で、各章に属する', () {
    final expanded = readings.where((r) => _expandedId.hasMatch(r.readingId)).toList();
    expect(expanded.length, greaterThanOrEqualTo(8), reason: '第1弾は8章以上');
    for (final r in expanded) {
      expect(r.sourceRef, contains('ai-draft'), reason: r.readingId);
      expect(r.sections.length, inInclusiveRange(4, 6), reason: r.readingId);
      expect(r.readingId, startsWith('reading-${r.subjectId}-'), reason: r.readingId);
      expect(r.relatedTermIds, isNotEmpty, reason: r.readingId);
      expect(r.relatedQuestionIds, isNotEmpty, reason: r.readingId);
      expect(r.title.length, lessThanOrEqualTo(30),
          reason: '${r.readingId}: 一覧で折り返しすぎないタイトル長');
      for (final s in r.sections) {
        expect(s.body.length, greaterThanOrEqualTo(80), reason: '${r.readingId}/${s.heading}');
      }
    }
  });

  test('非公式アプリとして禁止する断定表現・URLを含まない（拡充分）', () {
    for (final r in readings.where((r) => _expandedId.hasMatch(r.readingId))) {
      final text = [
        r.title,
        r.sourceRef,
        for (final s in r.sections) ...[s.heading, s.body],
      ].join('\n');
      for (final w in _forbidden) {
        expect(text, isNot(contains(w)), reason: '${r.readingId}: 「$w」');
      }
      expect(text, isNot(contains('http')), reason: '${r.readingId}: URL');
    }
  });
}
