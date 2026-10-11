import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

Future<List<ChapterReading>> loadChapterReadings() async {
  final text = await rootBundle.loadString('content/exam/reading.jsonl');
  final parsed = parseChapterReadingsJsonl(text);
  if (parsed.issues.isNotEmpty) {
    throw StateError('章ごとの解説読み物のデータに不備があります: ${parsed.issues.first}');
  }
  return parsed.items.where((r) => !r.disabled).toList();
}

final chapterReadingsProvider = FutureProvider<List<ChapterReading>>(
  (ref) => loadChapterReadings(),
);
