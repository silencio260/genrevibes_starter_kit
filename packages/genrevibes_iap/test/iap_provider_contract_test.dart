import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:test/test.dart';

import 'support/fake_iap_provider.dart';

void main() {
  test('provider can initialize, identify, read, and dispose', () async {
    final provider = FakeIapProvider(
      snapshot: EntitlementSnapshot(
        entitlements: const <Entitlement>[],
        observedAt: DateTime.utc(2026),
        provider: 'fake',
      ),
    );

    final initializeResult = await provider.initialize();
    expect(initializeResult.isSuccess, isTrue);
    expect(provider.health.state, ModuleState.ready);

    final identifyResult = await provider.identify('portfolio-user-1');
    expect(
      identifyResult.fold(
        onSuccess: (snapshot) => snapshot.appUserId,
        onFailure: (_) => null,
      ),
      'portfolio-user-1',
    );

    final entitlementResult = await provider.getEntitlements();
    expect(entitlementResult.isSuccess, isTrue);

    final disposeResult = await provider.dispose();
    expect(disposeResult.isSuccess, isTrue);
    expect(provider.health.state, ModuleState.disposed);
  });
}
