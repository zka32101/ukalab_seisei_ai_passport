// 体験ラボの選択肢の折り返し・今月のAI動向の表示・弱点の論点名の確認。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/ai_news_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/exam_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/oshi_recap.dart';
import 'package:ukalab_seisei_ai_passport/screens/ai_news_screen.dart';
import 'package:ukalab_seisei_ai_passport/widgets/lab/wrapped_confusion_matrix_lab_widget.dart';
import 'package:ukalab_seisei_ai_passport/widgets/lab/wrapped_failure_gallery_widget.dart';
import 'package:ukalab_seisei_ai_passport/widgets/lab/wrapped_teach_mascot_widget.dart';

const _longText =
    '事前学習は言語の基礎能力の獲得、RLHFは人間の好みに沿った出力への調整であり、'
    'どちらも欠かせない段階だと説明する選択肢';

Question _q(String qid, {String topicId = 'rlhf-vs-pretraining-goal', String prompt = 'p'}) =>
    Question(
      qid: qid,
      examId: 'seisei_ai_passport',
      subjectId: 'ch2',
      topicId: topicId,
      prompt: prompt,
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

/// 狭い幅(280dp)・大きい文字(x3)で [child] を描画し、例外が出ないこと、
/// 長い選択肢が折り返されて全文が描画されていること([longText])を確かめる。
Future<void> _expectWraps(WidgetTester tester, Widget child, String longText) async {
  tester.view.physicalSize = const Size(280, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
  final p = tester.renderObject<RenderParagraph>(find.text(longText).first);
  expect(p.softWrap, isTrue);
  final lines = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: longText.length));
  expect(lines.length, greaterThan(1), reason: '選択肢が1行に押し込まれている');
}

void main() {
  testWidgets('失敗図鑑: 長い選択肢・凡例が狭い幅+大きい文字でも折り返して全文出る', (tester) async {
    await _expectWraps(
      tester,
      WrappedFailureGalleryWidget(
        title: '症例 1',
        curve: const [
          LearningCurvePointSpec(epoch: 1, trainLoss: 1.0, valLoss: 1.1),
          LearningCurvePointSpec(epoch: 2, trainLoss: 0.5, valLoss: 0.9),
        ],
        symptomOptions: const [
          FailureChoiceSpec(optionId: 'a', text: _longText, isCorrect: true),
          FailureChoiceSpec(optionId: 'b', text: '未学習', isCorrect: false),
        ],
        treatmentOptions: const [],
        explanation: '解説',
      ),
      _longText,
    );
  });

  testWidgets('推しの答案を添削: 長い選択肢が折り返して全文出る', (tester) async {
    await _expectWraps(
      tester,
      WrappedTeachMascotWidget(
        title: '添削',
        statementTemplate: '{blank} が正しい',
        options: const [
          MisconceptionChoiceSpec(optionId: 'a', text: _longText, isCorrect: false),
          MisconceptionChoiceSpec(optionId: 'b', text: '正しい語', isCorrect: true),
        ],
        explanation: '解説',
      ),
      _longText,
    );
  });

  testWidgets('評価指標ラボ: 長い選択肢が折り返して全文出る', (tester) async {
    await _expectWraps(
      tester,
      WrappedConfusionMatrixLabWidget(
        scenario: ConfusionMatrixScenarioSpec(
          title: '場面',
          description: '説明',
          initialTp: 10,
          initialFp: 5,
          initialFn: 5,
          initialTn: 80,
          options: const [
            FailureChoiceSpec(optionId: 'a', text: _longText, isCorrect: true),
            FailureChoiceSpec(optionId: 'b', text: '短い', isCorrect: false),
          ],
          explanation: '解説',
        ),
      ),
      _longText,
    );
  });

  testWidgets('今月のAI動向: 「試験に出そう」の表示は出さない', (tester) async {
    final items = parseAiNewsItemsJsonl(File('content/news/news.jsonl').readAsStringSync())
        .items
        .where((i) => !i.disabled)
        .toList();
    expect(items.any((i) => i.isExamRelevant), isTrue, reason: '前提: データ上は旧バッジの対象がある');
    final exam = ExamConfig.fromJson(jsonDecode(
        File('content/exam/seisei_ai_passport.json').readAsStringSync()) as Map<String, dynamic>);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        aiNewsItemsProvider.overrideWith((ref) => items),
        examDataProvider.overrideWith((ref) => ExamData(exam: exam, questions: [_q('q1')])),
      ],
      child: const MaterialApp(home: AiNewsScreen()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('時点'), findsWidgets);
    expect(find.textContaining('試験に出'), findsNothing);
  });

  group('weakTopicLabelFor', () {
    test('論点IDは問題文の先頭で表し、IDそのものは出さない', () {
      final label = weakTopicLabelFor(
        [_q('q1', prompt: '事前学習とRLHFは、それぞれモデルのどのような側面を主に高めることを目的としているか。')],
        (_) => null,
        maxChars: 10,
      );
      expect(label('rlhf-vs-pretraining-goal'), '事前学習とRLHFは…');
    });

    test('科目IDなら科目名、引けなければ汎用の名前(slugは出さない)', () {
      final label = weakTopicLabelFor([_q('q1')], (id) => id == 'ch1' ? '1章 AIの基礎' : null);
      expect(label('ch1'), '1章 AIの基礎');
      final unknown = label('unknown-topic-slug');
      expect(unknown, 'この論点');
      expect(unknown.contains('-'), isFalse);
    });
  });
}
