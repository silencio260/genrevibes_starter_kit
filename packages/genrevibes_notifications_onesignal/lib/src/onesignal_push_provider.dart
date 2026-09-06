import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';

import 'onesignal_client.dart';
import 'onesignal_configuration.dart';

/// OneSignal implementation with idempotent observer registration and cleanup.
final class OneSignalPushProvider implements PushNotificationProvider {
  /// Creates a OneSignal push provider.
  OneSignalPushProvider({
    required GenRevibesOneSignalConfiguration configuration,
    OneSignalClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client ?? DefaultOneSignalClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'notifications.push.onesignal',
          provider: 'onesignal',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final GenRevibesOneSignalConfiguration _configuration;
  final OneSignalClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<PushEvent> _events =
      StreamController<PushEvent>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;
  bool _listenersAttached = false;

  @override
  String get moduleId => 'notifications.push.onesignal';

  @override
  String get providerId => 'onesignal';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Stream<PushEvent> get events => _events.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    if (_configuration.appId.trim().isEmpty) {
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'OneSignal app ID must not be empty.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }

    _setHealth(ModuleState.initializing);
    try {
      await _client.configurePrivacy(
        consentRequired: _configuration.consentRequired,
        consentGranted: _configuration.consentGranted,
      );
      await _client.setVerboseLogging(_configuration.verboseLogging);
      _attachListeners();
      _client.initialize(_configuration.appId.trim());
      _initialized = true;
      final state = await _readState();
      _setHealth(ModuleState.ready, details: state.toSafeDiagnostics());
      _emitState('initialize', state);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      _detachListeners();
      final mapped =
          _providerError('OneSignal initialization failed', error, stackTrace);
      _setHealth(ModuleState.failed, error: mapped);
      return KitFailure<void>(mapped);
    }
  }

  @override
  Future<KitResult<PushSubscriptionState>> getSubscriptionState() async {
    final notReady = _requireReady<PushSubscriptionState>();
    if (notReady != null) return notReady;
    try {
      final state = await _readState();
      _setHealth(ModuleState.ready, details: state.toSafeDiagnostics());
      return KitSuccess<PushSubscriptionState>(state);
    } on Object catch (error, stackTrace) {
      return KitFailure<PushSubscriptionState>(
        _providerError('Unable to read OneSignal state', error, stackTrace),
      );
    }
  }

  @override
  Future<KitResult<PushSubscriptionState>> requestPermission({
    bool fallbackToSettings = false,
  }) =>
      _mutateState(
        'permission',
        () => _client.requestPermission(
          fallbackToSettings: fallbackToSettings,
        ),
      );

  @override
  Future<KitResult<PushSubscriptionState>> optIn() =>
      _mutateState('optIn', _client.optIn);

  @override
  Future<KitResult<PushSubscriptionState>> optOut() =>
      _mutateState('optOut', _client.optOut);

  @override
  Future<KitResult<void>> identify(String externalUserId) {
    final id = externalUserId.trim();
    if (id.isEmpty) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'OneSignal external user ID must not be empty.',
          ),
        ),
      );
    }
    return _guard(() => _client.login(id));
  }

  @override
  Future<KitResult<void>> resetIdentity() => _guard(_client.logout);

  @override
  Future<KitResult<void>> setTags(Map<String, String> tags) {
    final sanitized = <String, String>{
      for (final entry in tags.entries)
        if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value,
    };
    if (sanitized.length != tags.length) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'OneSignal tag keys must not be empty.',
          ),
        ),
      );
    }
    return _guard(() => _client.setTags(sanitized));
  }

  @override
  Future<KitResult<void>> removeTags(Iterable<String> keys) {
    final sanitized = keys.map((key) => key.trim()).toList(growable: false);
    if (sanitized.any((key) => key.isEmpty)) {
      return Future<KitResult<void>>.value(
        const KitFailure<void>(
          KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'OneSignal tag keys must not be empty.',
          ),
        ),
      );
    }
    return _guard(() => _client.removeTags(sanitized));
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _detachListeners();
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _events.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<PushSubscriptionState>> _mutateState(
    String reason,
    Future<void> Function() operation,
  ) async {
    final notReady = _requireReady<PushSubscriptionState>();
    if (notReady != null) return notReady;
    try {
      await operation();
      final state = await _readState();
      _setHealth(ModuleState.ready, details: state.toSafeDiagnostics());
      _emitState(reason, state);
      return KitSuccess<PushSubscriptionState>(state);
    } on Object catch (error, stackTrace) {
      return KitFailure<PushSubscriptionState>(
        _providerError('OneSignal operation failed', error, stackTrace),
      );
    }
  }

  Future<KitResult<void>> _guard(Future<void> Function() operation) async {
    final notReady = _requireReady<void>();
    if (notReady != null) return notReady;
    try {
      await operation();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(
        _providerError('OneSignal operation failed', error, stackTrace),
      );
    }
  }

  Future<PushSubscriptionState> _readState() async {
    final state = await _client.getState();
    return PushSubscriptionState(
      providerId: providerId,
      permission: switch (state.permission) {
        OneSignalClientPermission.unknown => PushPermissionStatus.unknown,
        OneSignalClientPermission.notDetermined =>
          PushPermissionStatus.notDetermined,
        OneSignalClientPermission.denied => PushPermissionStatus.denied,
        OneSignalClientPermission.authorized => PushPermissionStatus.authorized,
        OneSignalClientPermission.provisional =>
          PushPermissionStatus.provisional,
        OneSignalClientPermission.ephemeral => PushPermissionStatus.ephemeral,
      },
      canRequestPermission: state.canRequestPermission,
      optedIn: state.optedIn,
      subscriptionId: state.subscriptionId,
      pushToken: state.pushToken,
      externalUserId: state.externalUserId,
      observedAt: _clock.now(),
    );
  }

  void _attachListeners() {
    if (_listenersAttached) return;
    _client.addPermissionListener(_onPermissionChanged);
    _client.addSubscriptionListener(_onSubscriptionChanged);
    _client.addForegroundListener(_onForegroundMessage);
    _client.addClickListener(_onMessageOpened);
    _listenersAttached = true;
  }

  void _detachListeners() {
    if (!_listenersAttached) return;
    _client.removePermissionListener(_onPermissionChanged);
    _client.removeSubscriptionListener(_onSubscriptionChanged);
    _client.removeForegroundListener(_onForegroundMessage);
    _client.removeClickListener(_onMessageOpened);
    _listenersAttached = false;
  }

  void _onPermissionChanged() => _refreshFromObserver('permission');

  void _onSubscriptionChanged() => _refreshFromObserver('subscription');

  void _refreshFromObserver(String reason) {
    unawaited(() async {
      if (!_initialized || _disposed) return;
      try {
        final state = await _readState();
        _setHealth(ModuleState.ready, details: state.toSafeDiagnostics());
        _emitState(reason, state);
      } on Object catch (error, stackTrace) {
        _logger.log(
          KitLogLevel.warning,
          'Unable to refresh OneSignal observer state.',
          moduleId: moduleId,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }());
  }

  void _onForegroundMessage(OneSignalClientMessage message) {
    if (!_events.isClosed) {
      _events.add(PushMessageReceived(_mapMessage(message)));
    }
  }

  void _onMessageOpened(OneSignalClientMessage message) {
    if (!_events.isClosed) {
      _events.add(PushMessageOpened(_mapMessage(message)));
    }
  }

  PushMessage _mapMessage(OneSignalClientMessage message) => PushMessage(
        messageId: message.id,
        title: message.title,
        body: message.body,
        actionId: message.actionId,
        additionalData: message.additionalData,
      );

  void _emitState(String reason, PushSubscriptionState state) {
    if (!_events.isClosed) {
      _events.add(PushStateChanged(reason: reason, state: state));
    }
  }

  KitFailure<T>? _requireReady<T>() =>
      _initialized && !_disposed ? null : _notReady<T>();

  KitFailure<T> _notReady<T>() => KitFailure<T>(
        const KitError(
          code: KitErrorCode.notInitialized,
          message: 'OneSignal has not been initialized.',
        ),
      );

  KitError _providerError(String message, Object error, StackTrace stackTrace) {
    _logger.log(
      KitLogLevel.warning,
      message,
      moduleId: moduleId,
      error: error,
      stackTrace: stackTrace,
    );
    return KitError(
      code: KitErrorCode.provider,
      message: '$message: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  void _setHealth(
    ModuleState state, {
    KitError? error,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: details,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
