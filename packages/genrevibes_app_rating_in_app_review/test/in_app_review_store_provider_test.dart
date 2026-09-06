import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_app_rating_in_app_review/genrevibes_app_rating_in_app_review.dart';
import 'package:genrevibes_app_rating_test/genrevibes_app_rating_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

void main() {
  runStoreReviewProviderContractTests(
    providerName: 'InAppReview',
    createProvider: () async => InAppReviewStoreProvider(
      client: _FakeReviewClient(),
      isIos: false,
    ),
  );

  group('InAppReviewStoreProvider', () {
    test('uses the native flow when the platform offers it', () async {
      final client = _FakeReviewClient();
      final provider = await _ready(client);

      await provider.requestReview();

      expect(client.requestReviewCount, 1);
      expect(client.openStoreListingCount, 0);
    });

    test('falls back to the listing when the native flow is unavailable',
        () async {
      // Platforms quota-limit the in-app flow, so this is a normal path, not
      // an error path.
      final client = _FakeReviewClient()..available = false;
      final provider = await _ready(client);

      final result = await provider.requestReview();

      expect(result.isSuccess, isTrue);
      expect(client.requestReviewCount, 0);
      expect(client.openStoreListingCount, 1);
    });

    test('a throwing native flow still reaches the listing', () async {
      final client = _FakeReviewClient()..requestError = StateError('no ui');
      final provider = await _ready(client);

      final result = await provider.requestReview();

      expect(result.isSuccess, isTrue);
      expect(client.openStoreListingCount, 1);
    });

    test('prefers the configured Android URL on Android', () async {
      final client = _FakeReviewClient();
      final provider = await _ready(
        client,
        configuration: const InAppReviewConfiguration(
          androidStoreUrl: 'https://play.google.com/store/apps/details?id=x',
          iosStoreUrl: 'https://apps.apple.com/app/id1',
        ),
        isIos: false,
      );

      await provider.openStoreListing();

      expect(client.launchedUrl, contains('play.google.com'));
      expect(client.openStoreListingCount, 0);
    });

    test('prefers the configured iOS URL on iOS', () async {
      final client = _FakeReviewClient();
      final provider = await _ready(
        client,
        configuration: const InAppReviewConfiguration(
          androidStoreUrl: 'https://play.google.com/store/apps/details?id=x',
          iosStoreUrl: 'https://apps.apple.com/app/id1',
        ),
        isIos: true,
      );

      await provider.openStoreListing();

      expect(client.launchedUrl, contains('apps.apple.com'));
    });

    test('falls back to the plugin listing when the URL will not launch',
        () async {
      final client = _FakeReviewClient()..canLaunch = false;
      final provider = await _ready(
        client,
        configuration: const InAppReviewConfiguration(
          androidStoreUrl: 'https://play.google.com/store/apps/details?id=x',
        ),
        isIos: false,
      );

      final result = await provider.openStoreListing();

      expect(result.isSuccess, isTrue);
      expect(client.openStoreListingCount, 1);
    });

    test('a listing failure is reported as a provider error', () async {
      final client = _FakeReviewClient()..listingError = StateError('no store');
      final provider = await _ready(client);

      final result = await provider.openStoreListing();

      expect(result.isFailure, isTrue);
      result.fold(
        onSuccess: (_) => fail('expected a failure'),
        onFailure: (error) {
          expect(error.code, KitErrorCode.provider);
          expect(error.providerCode, 'in_app_review_open_store_listing');
        },
      );
      expect(provider.health.state, ModuleState.degraded);
    });

    test('reports availability from the platform', () async {
      final provider = await _ready(_FakeReviewClient()..available = false);

      final result = await provider.isAvailable();

      expect(result.fold(onSuccess: (v) => v, onFailure: (_) => null), isFalse);
    });
  });

  group('InAppReviewConfiguration', () {
    test('reports whether any fallback URL exists', () {
      expect(const InAppReviewConfiguration().hasFallback, isFalse);
      expect(
        const InAppReviewConfiguration(androidStoreUrl: 'https://x')
            .hasFallback,
        isTrue,
      );
      expect(
        const InAppReviewConfiguration(androidStoreUrl: '').hasFallback,
        isFalse,
      );
    });
  });
}

Future<InAppReviewStoreProvider> _ready(
  _FakeReviewClient client, {
  InAppReviewConfiguration configuration = const InAppReviewConfiguration(),
  bool isIos = false,
}) async {
  final provider = InAppReviewStoreProvider(
    client: client,
    configuration: configuration,
    isIos: isIos,
  );
  await provider.initialize();
  return provider;
}

final class _FakeReviewClient implements ReviewClient {
  bool available = true;
  bool canLaunch = true;
  Object? requestError;
  Object? listingError;
  int requestReviewCount = 0;
  int openStoreListingCount = 0;
  String? launchedUrl;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    final error = requestError;
    if (error != null) throw error;
    requestReviewCount++;
  }

  @override
  Future<void> openStoreListing() async {
    final error = listingError;
    if (error != null) throw error;
    openStoreListingCount++;
  }

  @override
  Future<bool> launchStoreUrl(String url) async {
    if (!canLaunch) return false;
    launchedUrl = url;
    return true;
  }
}
