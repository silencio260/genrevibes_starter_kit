import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  const placement = AdPlacement(
    id: 'download_complete',
    format: AdFormat.interstitial,
  );

  test('blocks premium users and active suppression reasons', () {
    final policy = AdPolicyController(isPremium: true);
    expect(policy.evaluate(placement).blockReason, AdPolicyBlockReason.premium);

    policy.setPremium(false);
    policy.suppress('paywall');
    policy.suppress('paywall');
    expect(
      policy.evaluate(placement).blockReason,
      AdPolicyBlockReason.suppressed,
    );
    policy.release('paywall');
    expect(
      policy.evaluate(placement).blockReason,
      AdPolicyBlockReason.suppressed,
    );
    policy.release('paywall');
    expect(policy.evaluate(placement).isAllowed, isTrue);
  });

  test('enforces first-show and repeat intervals', () {
    final clock = _FakeClock(DateTime(2026));
    final policy = AdPolicyController(
      clock: clock,
      placements: const <String, AdPlacementPolicy>{
        'download_complete': AdPlacementPolicy(
          initialDelay: Duration(seconds: 3),
          minimumInterval: Duration(seconds: 10),
        ),
      },
    );

    expect(
      policy.evaluate(placement).blockReason,
      AdPolicyBlockReason.initialDelay,
    );
    clock.advance(const Duration(seconds: 3));
    expect(policy.beginShow(placement).isAllowed, isTrue);
    policy.recordShown(placement);
    policy.finishShow(placement);
    expect(
      policy.evaluate(placement).blockReason,
      AdPolicyBlockReason.frequencyCap,
    );
    clock.advance(const Duration(seconds: 10));
    expect(policy.evaluate(placement).isAllowed, isTrue);
  });

  test('suppression is always released when an action throws', () async {
    final policy = AdPolicyController();

    await expectLater(
      policy.whileSuppressed<void>(
          'paywall', () async => throw StateError('x')),
      throwsStateError,
    );

    expect(policy.suppressionReasons, isEmpty);
  });

  test('full-screen lock prevents overlapping ads', () {
    final policy = AdPolicyController();
    const other = AdPlacement(id: 'resume', format: AdFormat.appOpen);

    expect(policy.beginShow(placement).isAllowed, isTrue);
    expect(
      policy.beginShow(other).blockReason,
      AdPolicyBlockReason.anotherAdShowing,
    );
    policy.finishShow(placement);
    expect(policy.beginShow(other).isAllowed, isTrue);
  });
}

final class _FakeClock implements KitClock {
  _FakeClock(this.value);

  DateTime value;

  void advance(Duration duration) => value = value.add(duration);

  @override
  DateTime now() => value;
}
