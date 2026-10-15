import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show UkalabCertProp, UkalabProps;

/// 生成AIパスポートの資格小物。生成AI（画面の向こうのAI）を表す「モニター」を使う。ITパスの「チップ」と被らない。
/// 装飾のみ（読み上げ・タップ対象外）。画像の読み込みに失敗したら何も出さない。
class CertPropBadge extends StatelessWidget {
  const CertPropBadge({super.key, this.size = 44, this.prop = UkalabCertProp.monitor});

  final double size;
  final UkalabCertProp prop;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Image(
          image: UkalabProps.certImage(prop),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
