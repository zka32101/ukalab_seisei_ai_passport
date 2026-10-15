import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart' show PeerStatsSettings;

/// 参加スイッチを設定画面に出すか。送信側（PeerStatsSink）が存在しない間は
/// 誤解を招くため **false のまま**にする。送信を実装する PR で true にする。
const bool kPeerStatsSettingsVisible = false;

/// 「匿名の集計に参加する」スイッチ。説明文つき。現在は設定の保存だけを行う。
class PeerStatsSettingsTile extends StatefulWidget {
  const PeerStatsSettingsTile({super.key, required this.settings});

  final PeerStatsSettings settings;

  @override
  State<PeerStatsSettingsTile> createState() => _PeerStatsSettingsTileState();
}

class _PeerStatsSettingsTileState extends State<PeerStatsSettingsTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    widget.settings.isSharingEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await widget.settings.setSharingEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('匿名の集計に参加する'),
      subtitle: const Text(
        'オンにすると、1日1回、次の3つだけを匿名で送ります：連続学習日数・累計の問題数・試験日。'
        '名前・メール・端末を特定できる情報は送りません。'
        'オフのままでも、みんなの集計は見られます。いつでも切り替えられます。',
      ),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}
