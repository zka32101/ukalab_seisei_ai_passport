import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_seisei_ai_passport/data/character_wiring.dart';

void main() {
  ProviderContainer make(bool premium) {
    final c = ProviderContainer(overrides: [
      ...characterOverrides,
      entitlementStateProvider.overrideWith((ref) => Stream.value(EntitlementState(hasPremium: premium))),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('appId は ukalab_core 側の gen_ai_passport', () {
    expect(make(false).read(characterAppIdProvider), 'gen_ai_passport');
  });

  test('無料は false、プレミアムは true', () async {
    final free = make(false);
    await free.read(entitlementStateProvider.future);
    expect(free.read(characterPremiumProvider), isFalse);
    final prem = make(true);
    await prem.read(entitlementStateProvider.future);
    expect(prem.read(characterPremiumProvider), isTrue);
  });
}
