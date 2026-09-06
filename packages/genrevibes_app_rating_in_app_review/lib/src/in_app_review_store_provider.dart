import 'dart:async';
import 'dart:io' show Platform;

import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'in_app_review_client.dart';
import 'in_app_review_configuration.dart';

/// Platform in-app review implementation of [StoreReviewProvider].
///
/// Falls back to opening the store listing when the native review flow is
/// unavailable, which is common: platforms quota-limit the in-app flow and
/// decline silently once a user has seen it recently.
final class InAppReviewStoreProvider implements StoreReviewProvider {
  /// Creates an in-app review provider.
  InAppReviewStoreProvider({
    this.configuration = const InAppReviewConfiguration(),
    ReviewClient client = const DefaultReviewClient(),
    bool? isIos,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client,
        _isIos = isIos ?? _detectIos(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'app_rating.store',
          provider: 'in_app_review',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Store listing URLs used when the native flow is unavailable.
  final InAppReviewConfiguration configuration;

  final ReviewClient _client;
  final bool _isIos;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  static bool _detectIos() {
    // Guarded so the adapter can still be constructed on a host test VM.
    try {
      return Platform.isIOS || Platform.isMacOS;
    } on Object {
      return false;
    }
  }

  @override
  String get providerId => 'in_app_review';

  @override
  String get moduleId => 'app_rating.store';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    if (!configuration.hasFallback) {
      _logger.log(
        KitLogLevel.info,
        'No store listing URL configured. A user who chooses to review will '
        'have no path when the platform declines the in-app flow.',
        moduleId: moduleId,
      );
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<bool>> isAvailable() async {
    if (!_initialized || _disposed) return _notReady<bool>();
    try {
      return KitSuccess<bool>(await _client.isAvailable());
    } on Object catch (error, stackTrace) {
      return _failure<bool>(error, stackTrace, 'is_available');
    }
  }

  @override
  Future<KitResult<void>> requestReview() async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      if (await _client.isAvailable()) {
        await _client.requestReview();
        return const KitSuccess<void>(null);
      }
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'In-app review request failed. Falling back to the store listing.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
    }
    return openStoreListing();
  }

  @override
  Future<KitResult<void>> openStoreListing() async {
    if (!_initialized || _disposed) return _notReady<void>();
    final url =
        _isIos ? configuration.iosStoreUrl : configuration.androidStoreUrl;
    try {
      if (url != null && url.isNotEmpty) {
        if (await _client.launchStoreUrl(url)) {
          return const KitSuccess<void>(null);
        }
      }
      await _client.openStoreListing();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'open_store_listing');
    }
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  KitFailure<T> _failure<T>(
    Object error,
    StackTrace stackTrace,
    String providerCode,
  ) {
    final mapped = KitError(
      code: KitErrorCode.provider,
      message: 'In-app review $providerCode failed: $error',
      providerCode: 'in_app_review_$providerCode',
      cause: error,
      stackTrace: stackTrace,
    );
    if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
    return KitFailure<T>(mapped);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Store review provider has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
