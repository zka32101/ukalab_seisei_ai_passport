import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'core_features.dart';

/// 間違いノートの保存先(端末内)。
/// 保存するのは問題ID・日時・原因コード・分野ID・回数だけ。バックアップ/リセットの対象
/// ([seiseiDataParts] の `mistakeNotes`)も同じストアを使う。
final MistakeNoteStore mistakeNoteStore = SharedPreferencesMistakeNoteStore(kExamId);

const MistakeNoteEngine mistakeNoteEngine = MistakeNoteEngine();
