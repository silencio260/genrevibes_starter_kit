import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_notifications/genrevibes_notifications.dart';

import 'flutter_local_notifications_client.dart';
import 'local_notifications_configuration.dart';

/// Persistent OS-backed local notification scheduler.
final class PersistentLocalNotificationScheduler
    implements LocalNotificationScheduler {
  /// Creates a local notification scheduler.
  PersistentLocalNotificationScheduler({
    required GenRevibesLocalNotificationsConfiguration configuration,
    FlutterLocalNotificationsClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client ?? DefaultFlutterLocalNotificationsClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'notifications.local',
          provider: 'flutter_local_notifications',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final GenRevibesLocalNotificationsConfiguration _configuration;
  final FlutterLocalNotificationsClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<LocalNotificationInteraction> _interactions =
      StreamController<LocalNotificationInteraction>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'notifications.local';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Stream<LocalNotificationInteraction> get interactions => _interactions.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    if (_configuration.androidDefaultIcon.trim().isEmpty ||
        _configuration.timeZoneName.trim().isEmpty) {
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'Android icon and IANA timezone must not be empty.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    _setHealth(ModuleState.initializing);
    try {
      await _client.initialize(_configuration, _onInteraction);
      _initialized = true;
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = _providerError(
        'Local notification initialization failed',
        error,
        stackTrace,
      );
      _setHealth(ModuleState.failed, error: mapped);
      return KitFailure<void>(mapped);
    }
  }

  @override
  Future<KitResult<bool>> requestPermission() =>
      _guard<bool>(_client.requestPermission);

  @override
  Future<KitResult<void>> show(
    int id,
    LocalNotificationContent content,
  ) {
    final invalid = _validate(id, content);
    if (invalid != null) return Future.value(invalid);
    return _guard<void>(() => _client.show(id, content));
  }

  @override
  Future<KitResult<void>> schedule(LocalNotificationRequest request) {
    final invalid = _validate(request.id, request.content);
    if (invalid != null) return Future.value(invalid);
    return switch (request.schedule) {
      LocalNotificationOnce(:final at) => at.isAfter(_clock.now())
          ? _guard<void>(() => _client.scheduleOnce(request, at))
          : Future<KitResult<void>>.value(
              const KitFailure<void>(
                KitError(
                  code: KitErrorCode.invalidConfiguration,
                  message: 'One-shot notification time must be in the future.',
                ),
              ),
            ),
      LocalNotificationInterval(:final every) =>
        _guard<void>(() => _client.scheduleInterval(request, every)),
      LocalNotificationDaily(:final hour, :final minute) => _guard<void>(
          () => _client.scheduleDaily(request, hour: hour, minute: minute),
        ),
    };
  }

  @override
  Future<KitResult<List<PendingLocalNotification>>> pending() =>
      _guard<List<PendingLocalNotification>>(() async =>
          (await _client.pendingIds())
              .map((id) => PendingLocalNotification(id: id))
              .toList(growable: false));

  @override
  Future<KitResult<void>> cancel(int id) =>
      _guard<void>(() => _client.cancel(id));

  @override
  Future<KitResult<void>> cancelAll() => _guard<void>(_client.cancelAll);

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _interactions.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<T>> _guard<T>(Future<T> Function() operation) async {
    final notReady = _requireReady<T>();
    if (notReady != null) return notReady;
    try {
      return KitSuccess<T>(await operation());
    } on Object catch (error, stackTrace) {
      return KitFailure<T>(
        _providerError(
            'Local notification operation failed', error, stackTrace),
      );
    }
  }

  KitFailure<void>? _validate(int id, LocalNotificationContent content) {
    if (id < 0 ||
        content.title.trim().isEmpty ||
        content.body.trim().isEmpty ||
        content.channelId.trim().isEmpty ||
        content.channelName.trim().isEmpty) {
      return const KitFailure<void>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Notification id, content, and channel must be valid.',
        ),
      );
    }
    return null;
  }

  void _onInteraction(LocalNotificationInteraction interaction) {
    if (!_interactions.isClosed) _interactions.add(interaction);
  }

  KitFailure<T>? _requireReady<T>() =>
      _initialized && !_disposed ? null : _notReady<T>();

  KitFailure<T> _notReady<T>() => KitFailure<T>(
        const KitError(
          code: KitErrorCode.notInitialized,
          message: 'Local notifications have not been initialized.',
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

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: 'flutter_local_notifications',
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
