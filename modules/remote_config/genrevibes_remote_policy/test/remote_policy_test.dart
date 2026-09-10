import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';
import 'package:genrevibes_remote_policy/genrevibes_remote_policy.dart';
import 'package:test/test.dart';

void main() {
  group('AdsPolicyConfig', () {
    test('defaults match the bundled production values', () {
      final config = AdsPolicyConfig.fromSnapshot(_snapshot());

      expect(config.enabled, isTrue);
      expect(config.firstInterstitialDelay, const Duration(seconds: 3));
      expect(config.interstitialInterval, const Duration(seconds: 5));
      expect(config.bannerInterval, const Duration(seconds: 3));
      expect(config.showAppOpenAd, isTrue);
      expect(config.unitOverride(AdFormat.banner), isNull);
    });

    test('reads remote overrides, including the misspelled production key', () {
      final config = AdsPolicyConfig.fromSnapshot(
        _snapshot(<String, Object?>{
          'min_insta_ad_interval': 45,
          'time_before_first_rewared_ad': 9,
          'should_show_app_open_ad': false,
          'interstitial_ad_id': ' ca-app-pub-1/2 ',
        }),
      );

      expect(config.interstitialInterval, const Duration(seconds: 45));
      expect(config.firstRewardedDelay, const Duration(seconds: 9));
      expect(config.showAppOpenAd, isFalse);
      expect(config.unitOverride(AdFormat.interstitial), 'ca-app-pub-1/2');
    });

    test('an invalid value falls back to the default', () {
      final config = AdsPolicyConfig.fromSnapshot(
        _snapshot(<String, Object?>{'min_insta_ad_interval': -1}),
      );

      expect(config.interstitialInterval, const Duration(seconds: 5));
    });

    test('maps formats to placement policies', () {
      final config = AdsPolicyConfig.fromSnapshot(
        _snapshot(<String, Object?>{'should_show_app_open_ad': false}),
      );

      final interstitial = config.policyFor(AdFormat.interstitial);
      expect(interstitial.initialDelay, const Duration(seconds: 3));
      expect(interstitial.minimumInterval, const Duration(seconds: 5));
      expect(config.policyFor(AdFormat.appOpen).enabled, isFalse);
      expect(config.policyFor(AdFormat.banner).enabled, isTrue);
    });

    test('the kill switch disables every format', () {
      final config = AdsPolicyConfig.fromSnapshot(
        _snapshot(<String, Object?>{'ads_enabled': false}),
      );

      for (final format in AdFormat.values) {
        expect(config.policyFor(format).enabled, isFalse, reason: '$format');
      }
    });
  });

  group('AdsRemotePolicyBinder', () {
    const placement =
        AdPlacement(id: 'home_inter', format: AdFormat.interstitial);

    test('applies the current snapshot at startup', () async {
      final policy = AdPolicyController();
      final binder = AdsRemotePolicyBinder(
        current: () =>
            _snapshot(<String, Object?>{'min_insta_ad_interval': 30}),
        changes: const Stream<RemoteConfigSnapshot>.empty(),
        policy: policy,
        placements: const <AdPlacement>[placement],
      );

      await binder.initialize();

      expect(
        policy.placements['home_inter']!.minimumInterval,
        const Duration(seconds: 30),
      );
    });

    test('retunes live on a change without losing suppression', () async {
      final policy = AdPolicyController()..suppress('paywall');
      final changes = StreamController<RemoteConfigSnapshot>();
      final binder = AdsRemotePolicyBinder(
        current: _snapshot,
        changes: changes.stream,
        policy: policy,
        placements: const <AdPlacement>[placement],
      );
      await binder.initialize();

      changes.add(_snapshot(<String, Object?>{'ads_enabled': false}));
      await Future<void>.delayed(Duration.zero);

      expect(policy.placements['home_inter']!.enabled, isFalse);
      expect(policy.suppressionReasons, contains('paywall'));
      expect(binder.applied!.enabled, isFalse);
      await binder.dispose();
      await changes.close();
    });
  });

  group('AnalyticsNamesSchema', () {
    test('every canonical name defaults to itself', () {
      for (final canonical in AnalyticsNamesSchema.canonicalNames) {
        expect(AnalyticsNamesSchema.keyFor(canonical)!.defaultValue, canonical);
      }
    });

    test('remote keys follow the historical event_ convention', () {
      expect(
        AnalyticsNamesSchema.remoteKeyFor('custom_paywall_cancelled'),
        'event_paywall_cancelled',
      );
      expect(
        AnalyticsNamesSchema.remoteKeyFor('retention_day_1_returned'),
        'event_day1_returned',
      );
    });

    test('the portfolio schema has no duplicate keys', () {
      // RemoteConfigSchema throws on duplicates; building it is the test.
      final schema = PortfolioRemoteConfigSchema.build(
        includeAnalyticsNames: true,
        appKeys: <RemoteConfigKey<Object?>>[
          remoteConfigKey(
            const RemoteConfigKey<bool>(
              name: 'app_feature',
              defaultValue: false,
              codec: RemoteConfigBoolCodec(),
            ),
          ),
        ],
      );

      expect(
        schema.keys.length,
        AdsPolicyKeys.all.length +
            SessionReplayPolicyKeys.all.length +
            AnalyticsNamesSchema.all.length +
            1,
      );
    });

    test('analytics name overrides are left out unless asked for', () {
      // Forty-two keys that only matter to an app renaming events remotely.
      // Including them by default buried the handful an app really configures.
      final schema = PortfolioRemoteConfigSchema.build();

      expect(
        schema.keys.length,
        AdsPolicyKeys.all.length + SessionReplayPolicyKeys.all.length,
      );
      expect(
        schema.byName.keys.any((name) => name.startsWith('event_')),
        isFalse,
      );
    });
  });

  group('RemoteAnalyticsEventNames', () {
    test('resolves an override and keeps unknown or blank names', () {
      final names = RemoteAnalyticsEventNames(
        current: () => _snapshot(<String, Object?>{
          'event_rating_submitted': 'rated',
          'event_share_app': '   ',
        }),
      );

      expect(names.resolve('rating_submitted'), 'rated');
      expect(names.resolve('share_app'), 'share_app');
      expect(names.resolve('not_a_known_event'), 'not_a_known_event');
    });

    test('plugs into the analytics pipeline resolver contract', () {
      final AnalyticsEventNames names = RemoteAnalyticsEventNames(
        current: _snapshot,
      );

      expect(names.resolve('app_open'), 'app_open');
    });
  });
}

RemoteConfigSnapshot _snapshot([Map<String, Object?> values = const {}]) {
  return RemoteConfigSnapshot(
    values: values,
    origins: <String, RemoteConfigValueOrigin>{
      for (final key in values.keys) key: RemoteConfigValueOrigin.remote,
    },
    observedAt: DateTime(2026),
  );
}
