// 文字切れ・はみ出しの動的検証。
//
// 幅 320/280dp × 文字倍率 1/2/3 で主要画面を実際に描画し、RenderFlex overflow などの
// レイアウト例外が出ないことを確かめる。問題・用語は content/ の実データ(長いものを先頭に並べ替え)を
// そのまま使う(データ・ロジックは変えない)。外部サービス(課金・読み上げ・保存先)は Fake / モック。
import 'dart:convert';
import 'dart:io';

import 'package:app_common_kit/app_common_kit.dart'
    show
        EntitlementState,
        FakeEntitlementService,
        InMemoryHandsFreeStore,
        entitlementServiceProvider,
        handsFreeStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderObject, RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/achievements.dart'
    show achievementUnlockOverrides, dailyGoalAchievementsOverride;
import 'package:ukalab_core/daily_goal.dart' show dailyGoalOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_seisei_ai_passport/data/ai_news_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/boundary_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/confusion_matrix_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/exam_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/failure_gallery_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/misconception_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/predict_run_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/reading_repository.dart';
import 'package:ukalab_seisei_ai_passport/data/term_repository.dart';
import 'package:ukalab_seisei_ai_passport/main.dart';
import 'package:ukalab_seisei_ai_passport/screens/ai_news_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/boundary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/confusion_matrix_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/exam_prep_entry.dart';
import 'package:ukalab_seisei_ai_passport/screens/failure_gallery_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/glossary_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/home_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/learn_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mistake_note_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/mock_exam_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/predict_run_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/reading_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/record_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/route_planner_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/settings_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/teach_mascot_screen.dart';
import 'package:ukalab_seisei_ai_passport/screens/term_map_screen.dart';

// ---------------------------------------------------------------- データ

String _read(String path) => File(path).readAsStringSync();

ExamConfig _exam() => ExamConfig.fromJson(
    jsonDecode(_read('content/exam/seisei_ai_passport.json')) as Map<String, dynamic>);

/// 実データのうち、文字が長い問題を先頭に並べる(選択肢・問題文・解説の最悪ケース)。
List<Question> _questions() {
  final all = parseQuestionsJsonl(_read('content/exam/questions.jsonl'))
      .questions
      .where((q) => !q.disabled)
      .toList();
  int score(Question q) =>
      q.prompt.length + q.explanation.length + q.choices.fold<int>(0, (a, c) => a + c.length);
  all.sort((a, b) => score(b).compareTo(score(a)));
  return all;
}

class _Data {
  _Data()
      : exam = _exam(),
        questions = _questions();
  final ExamConfig exam;
  final List<Question> questions;
}

// ---------------------------------------------------------------- 構成

const _sizes = [Size(320, 640), Size(280, 560)];
const _scales = [1.0, 2.0, 3.0];

/// 全画面共通の依存(Fake / モック)。
List<Override> _overrides(_Data d, {bool premium = false}) {
  return [
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService(
        initial: premium ? const EntitlementState(hasPremium: true) : EntitlementState.free)),
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    examDateStoreProvider.overrideWithValue(ExamDateStore('test')),
    dailyGoalAchievementsOverride,
    examDataProvider.overrideWith((ref) => ExamData(exam: d.exam, questions: d.questions)),
    termsProvider.overrideWith((ref) {
      final t = parseTermsJsonl(_read('content/exam/terms.jsonl')).terms.where((t) => !t.disabled);
      return t.toList();
    }),
    chapterReadingsProvider.overrideWith((ref) => parseChapterReadingsJsonl(
            _read('content/exam/reading.jsonl'))
        .items
        .where((r) => !r.disabled)
        .toList()),
    aiNewsItemsProvider.overrideWith((ref) => (parseAiNewsItemsJsonl(_read('content/news/news.jsonl'))
            .items
            .where((i) => !i.disabled)
            .toList()
          ..sort((a, b) => b.asOfDate.compareTo(a.asOfDate)))),
    boundaryScenariosProvider.overrideWith((ref) => parseBoundaryScenariosJsonl(
            _read('content/exam/boundary_scenarios.jsonl'))
        .scenarios
        .where((s) => !s.disabled)
        .toList()),
    confusionMatrixScenariosProvider.overrideWith((ref) => parseConfusionMatrixScenariosJsonl(
            _read('content/exam/confusion_matrix_scenarios.jsonl'))
        .scenarios
        .where((s) => !s.disabled)
        .toList()),
    failureCasesProvider.overrideWith((ref) =>
        parseFailureCasesJsonl(_read('content/exam/failure_gallery_cases.jsonl'))
            .cases
            .where((c) => !c.disabled)
            .toList()),
    misconceptionScenariosProvider.overrideWith((ref) => parseMisconceptionScenariosJsonl(
            _read('content/exam/teach_mascot_scenarios.jsonl'))
        .scenarios
        .where((s) => !s.disabled)
        .toList()),
    predictRunScenariosProvider.overrideWith((ref) => parsePredictRunScenariosJsonl(
            _read('content/exam/predict_run_scenarios.jsonl'))
        .scenarios
        .where((s) => !s.disabled)
        .toList()),
  ];
}

Future<List<Override>> _asyncOverrides(WidgetTester tester) async => [
      ...(await tester.runAsync(() => studyNotesOverrides('test')))!,
      ...(await tester.runAsync(() => dailyGoalOverrides('test')))!,
      ...(await tester.runAsync(() => reminderOverrides('test')))!,
      ...(await tester.runAsync(() => achievementUnlockOverrides('test')))!,
      ...(await tester.runAsync(() => mockExamHistoryOverrides('test')))!,
    ];

/// 全セクションを開いた状態 + 解答履歴(間違いを含む)の入った端末内保存。
Map<String, Object> _prefs(_Data d) {
  final now = DateTime.now();
  final records = <ProgressRecord>[];
  for (var i = 0; i < 18; i++) {
    final q = d.questions[i];
    records.add(historyRecordFor(q,
        correct: i % 3 == 0, ms: 4000, at: now.subtract(Duration(hours: i + 1))));
  }
  return {
    'ukalab_seisei_home_section_tools': true,
    'ukalab_seisei_home_section_lab': true,
    'ukalab_seisei_ai_passport_history_v1': encodeHistory(records),
  };
}

/// このアプリからは直せない、依存パッケージ側の既知のはみ出し(ファイル名)。
/// core / kit 側で直したら、ここから外す(外すと再発を検知できる)。
const _knownDependencyFiles = [
  'ui/answer_feedback/weak_summary_card.dart', // ホーム「弱点」カードの行(順位・件数)
  'ui/ui_kit/failure_gallery.dart', // 学習の失敗図鑑の凡例(訓練誤差/検証誤差)
  'ui/mistake_note/mistake_note_view.dart', // 間違いノートの見出し+絞り込み(縦)
];

/// レイアウト例外 1 件。[origin] は「エラーの原因ウィジェット」を作ったコードの位置(file:line)。
class _Issue {
  _Issue(this.message, this.origin);
  final String message;
  final String origin;

  /// 失敗として扱うか。このアプリ(lib/)・原因不明のものは常に失敗。
  /// ukalab_core / app_common_kit 側は、下の [_knownDependencyFiles] に載せた既知のものだけ失敗にしない。
  bool get isApp => origin.isEmpty || !_knownDependencyFiles.any(origin.contains);

  String get short {
    final o = origin
        .replaceAllMapped(RegExp(r'^file://.*?/(ukalab_core|app_common_kit)-[0-9a-f]+/'), (m) => '${m[1]}:')
        .replaceAll(RegExp(r'^file://.*?/(lib/)'), 'lib/');
    return '${message.split('. ').first}  @ $o';
  }
}

/// 例外を集めながら [body] を実行する。
Future<List<_Issue>> _collect(Future<void> Function() body) async {
  final errors = <_Issue>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final lines = details.toString().split('\n');
    final head = details.exceptionAsString().split('\n').first;
    final i = lines.indexWhere((l) => l.contains('error-causing widget'));
    var origin = '';
    if (i >= 0) {
      for (final l in lines.skip(i + 1).take(3)) {
        final m = RegExp(r'file://\S+?\.dart:\d+:\d+').firstMatch(l);
        if (m != null) {
          origin = m.group(0)!;
          break;
        }
      }
    }
    errors.add(_Issue(head, origin));
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
  return errors;
}

/// 描画済みの Text のうち、maxLines / ellipsis で文字が隠れているものを [out] に足す。
/// 画面外(スクロールで見えていない)ものは除く。
void _collectHiddenText(WidgetTester tester, String config, Set<String> out) {
  void visit(RenderObject r) {
    if (r is RenderParagraph && r.didExceedMaxLines) {
      final t = r.text.toPlainText();
      final c = r.debugCreator;
      final chain = c is DebugCreator ? c.element.debugGetCreatorChain(45).replaceAll(RegExp(r'\s+'), ' ') : '';
      final snippet = t.length > 40 ? '${t.substring(0, 40)}…' : t;
      // AppBar の題名・SnackBar はこのアプリが文言を渡している。それ以外(用語集の行・用語マップの
      // ノード等)は ukalab_core 側のウィジェット内で省略されている。
      final isApp = chain.contains('_AppBarTitleBox') || chain.contains('SnackBar');
      if (isApp) {
        out.add('$config: 文字が隠れている「$snippet」(${r.overflow.name})');
      } else {
        knownDependencyIssues.add('文字が隠れている(依存側): $snippet');
      }
    }
    r.visitChildren(visit);
  }

  final root = tester.binding.rootElement?.renderObject;
  if (root != null) visit(root);
}

/// 依存パッケージ(ukalab_core / app_common_kit)側が原因のはみ出し。このアプリでは直せないため
/// 失敗にはせず、テスト出力に列挙するだけ(報告用)。
final Set<String> knownDependencyIssues = <String>{};

/// 画面を [home] として描画し、スクロールして最後まで見る。[act] で画面内の操作を行う。
Future<void> _check(
  WidgetTester tester,
  Widget Function(_Data d) home, {
  Future<void> Function(WidgetTester t)? act,
  bool premium = false,
  bool wholeApp = false,
}) async {
  final d = _Data();
  final failures = <String>[];
  final hidden = <String>{};
  for (final size in _sizes) {
    for (final scale in _scales) {
      final cfg = '${size.width.toInt()}dp x$scale';
      SharedPreferences.setMockInitialValues(_prefs(d));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final overrides = [..._overrides(d, premium: premium), ...await _asyncOverrides(tester)];
      final errors = await _collect(() async {
        await tester.pumpWidget(UncontrolledProviderScope(
          container: ProviderContainer(overrides: overrides),
          child: wholeApp
              ? const UkalabSeiseiAiPassportApp()
              : MaterialApp(
                  theme: UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.genAiPassport),
                  home: home(d),
                ),
        ));
        await _settle(tester);
        await _scrollThrough(tester);
        _collectHiddenText(tester, cfg, hidden);
        if (act != null) {
          await act(tester);
          await _settle(tester);
          await _scrollThrough(tester);
          _collectHiddenText(tester, cfg, hidden);
        }
      });
      // 画面を破棄してから次の構成へ。
      await tester.pumpWidget(const SizedBox.shrink());
      for (final e in errors) {
        final line = '${size.width.toInt()}dp x$scale: ${e.short}';
        if (e.isApp) {
          if (!failures.contains(line)) failures.add(line);
        } else {
          knownDependencyIssues.add(e.short);
        }
      }
    }
  }
  failures.addAll(hidden);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  expect(failures, isEmpty, reason: failures.join('\n'));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// 画面内の縦スクロールを最後まで動かし、遅延構築される下の方も描画させる。
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 40; i++) {
    final vertical = scrollables.evaluate().where((e) {
      final w = e.widget as Scrollable;
      return w.axisDirection == AxisDirection.down;
    });
    if (vertical.isEmpty) return;
    final state = (vertical.first as StatefulElement).state as ScrollableState;
    final pos = state.position;
    if (pos.pixels >= pos.maxScrollExtent) return;
    pos.jumpTo((pos.pixels + 250).clamp(0, pos.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 下部ナビのタブを押す(ホームの見出し「記録」と同名のため、画面下側=最後の一致を押す)。
Future<void> _tapTab(WidgetTester tester, String label) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.last, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return;
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------- テスト

void main() {
  test('lib/ の文字は maxLines / ellipsis / clip / fade で隠さない(静的ガード)', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//')) continue;
        if (RegExp(r'maxLines|TextOverflow\.(ellipsis|clip|fade)').hasMatch(l)) {
          offenders.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  tearDownAll(() {
    if (knownDependencyIssues.isNotEmpty) {
      // ignore: avoid_print
      print('[依存パッケージ側のはみ出し・省略(このアプリでは未修正) ${knownDependencyIssues.length}件]\n${(knownDependencyIssues.toList()..sort()).take(60).join('\n')}');
    }
  });

  testWidgets('ホーム(全セクション展開・プレミアム)', (tester) async {
    await _check(tester, (d) => Scaffold(body: HomeScreen(exam: d.exam, questionCount: d.questions.length, questions: d.questions)),
        premium: true);
  });

  testWidgets('ホーム(無料)', (tester) async {
    await _check(tester, (d) => Scaffold(body: HomeScreen(exam: d.exam, questionCount: d.questions.length, questions: d.questions)));
  });

  testWidgets('アプリ全体: 下部ナビと5タブ(学ぶ/模擬/記録/設定)', (tester) async {
    await _check(tester, (d) => const SizedBox.shrink(), wholeApp: true, act: (t) async {
      for (final tab in ['学ぶ', '模擬', '記録', '設定']) {
        await _tapTab(t, tab);
        await _scrollThrough(t);
      }
    });
  });

  testWidgets('演習: 長い問題・選択肢・解説(誤答で原因ラベルも)', (tester) async {
    await _check(tester, (d) => Scaffold(body: LearnScreen(questions: d.questions.take(6).toList(), sessionSize: 3)),
        act: (t) async {
      for (var round = 0; round < 3; round++) {
        // 先頭の選択肢を押す。正解なら別の選択肢を押し直せないので、そのまま解説を見る。
        await _tapText(t, 'A');
        await _scrollThrough(t);
        await _tapText(t, '次へ');
      }
    });
  });

  testWidgets('演習: 結果画面', (tester) async {
    await _check(tester, (d) => Scaffold(body: LearnScreen(questions: d.questions.take(3).toList(), sessionSize: 1)),
        act: (t) async {
      await _tapText(t, 'B');
      await _tapText(t, '次へ');
    });
  });

  testWidgets('模擬試験: 開始前・出題・結果・カスタム設定', (tester) async {
    await _check(tester, (d) => Scaffold(body: MockExamScreen(exam: d.exam, questions: d.questions.take(8).toList())),
        premium: true, act: (t) async {
      await _tapText(t, 'カスタム模擬試験');
      await _scrollThrough(t);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await t.pump(const Duration(milliseconds: 400));
      await _tapText(t, '模擬試験を始める');
      for (var i = 0; i < 40; i++) {
        if (find.text('結果を見る').evaluate().isEmpty && find.text('次へ').evaluate().isEmpty) break;
        await _tapText(t, 'A');
        await _scrollThrough(t);
        if (find.text('結果を見る').evaluate().isNotEmpty) {
          await _tapText(t, '結果を見る');
          break;
        }
        await _tapText(t, '次へ');
      }
    });
  });

  testWidgets('記録タブ(復習予定・苦手分野)', (tester) async {
    await _check(tester, (d) => const Scaffold(body: RecordScreen()), act: (t) async {
      // 記録は演習の解答で作る。別のコンテナなので、ここでは空状態も含めて表示を確認する。
    });
  });

  testWidgets('アプリ全体: 演習で解答した後の記録タブ', (tester) async {
    await _check(tester, (d) => const SizedBox.shrink(), wholeApp: true, act: (t) async {
      await _tapTab(t, '学ぶ');
      await _tapText(t, 'A');
      await _scrollThrough(t);
      await _tapText(t, '次へ');
      await _tapText(t, 'A');
      await _tapTab(t, '記録');
      await _scrollThrough(t);
      await _tapText(t, '復習を始める');
      await _scrollThrough(t);
    });
  });

  testWidgets('設定タブ(ながら学習ON・プレミアム)', (tester) async {
    await _check(tester, (d) => Scaffold(body: SettingsScreen(questions: d.questions, exam: d.exam)),
        premium: true, act: (t) async {
      await _tapText(t, 'ながら学習モード');
      await _scrollThrough(t);
    });
  });

  testWidgets('設定: 試験日の設定・間違いノート・実績', (tester) async {
    await _check(tester, (d) => Scaffold(body: SettingsScreen(questions: d.questions, exam: d.exam)),
        act: (t) async {
      await _tapText(t, '実績');
      await _scrollThrough(t);
    });
  });

  testWidgets('試験日の設定画面', (tester) async {
    await _check(tester, (d) => const ExamDateSettingsScreen());
  });

  testWidgets('間違いノート', (tester) async {
    await _check(tester, (d) => MistakeNoteScreen(exam: d.exam, questions: d.questions));
  });

  testWidgets('今日やる3つ', (tester) async {
    await _check(tester, (d) => const RoutePlannerScreen());
  });

  testWidgets('用語集', (tester) async {
    await _check(tester, (d) => const GlossaryScreen(), act: (t) async {
      await _tapText(t, '指示チューニング（Instruction Tuning）');
    });
  });

  testWidgets('用語マップ + 用語カードのダイアログ', (tester) async {
    await _check(tester, (d) => const TermMapScreen(), act: (t) async {
      await _tapText(t, '指示チューニング（Instruction Tuning）');
      await _scrollThrough(t);
    });
  });

  testWidgets('章ごとの解説読み物(一覧と本文)', (tester) async {
    await _check(tester, (d) => const ReadingScreen(), premium: true, act: (t) async {
      await _tapText(t, '4章 生成AIのリスク予防・AI倫理・ガバナンス');
      await _scrollThrough(t);
    });
  });

  testWidgets('今月のAI動向', (tester) async {
    await _check(tester, (d) => const AiNewsScreen());
  });

  testWidgets('境界線スライダー', (tester) async {
    await _check(tester, (d) => const BoundaryScreen());
  });

  testWidgets('評価指標ラボ', (tester) async {
    await _check(tester, (d) => const ConfusionMatrixScreen());
  });

  testWidgets('学習の失敗図鑑', (tester) async {
    await _check(tester, (d) => const FailureGalleryScreen());
  });

  testWidgets('温度の実験室', (tester) async {
    await _check(tester, (d) => const PredictRunScreen());
  });

  testWidgets('推しの答案を添削', (tester) async {
    await _check(tester, (d) => const TeachMascotScreen());
  });
}
