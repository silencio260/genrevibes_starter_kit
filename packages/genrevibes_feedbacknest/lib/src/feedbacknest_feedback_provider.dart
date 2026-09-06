import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';

import 'feedbacknest_client.dart';
import 'feedbacknest_configuration.dart';

/// FeedbackNest implementation of [FeedbackProvider].
final class FeedbackNestFeedbackProvider implements FeedbackProvider {
  /// Creates a FeedbackNest feedback provider.
  FeedbackNestFeedbackProvider({
    required FeedbackNestConfiguration configuration,
    FeedbackNestClient client = const DefaultFeedbackNestClient(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _client = client,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'feedback',
          provider: 'feedbacknest',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final FeedbackNestConfiguration _configuration;
  final FeedbackNestClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'feedbacknest';

  @override
  String get moduleId => 'feedback';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    if (!_configuration.isValid) {
      // Fail loudly. A feedback provider that silently accepts and discards
      // reports is worse than none, because the app keeps offering the form.
      const error = KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'FeedbackNest requires a non-empty API key.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<void>(error);
    }
    try {
      await _client.initialize(
        _configuration.apiKey,
        userIdentifier: _configuration.userIdentifier,
      );
      _initialized = true;
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'initialize');
    }
  }

  @override
  Future<KitResult<void>> submit(FeedbackSubmission submission) async {
    if (!_initialized || _disposed) return _notReady<void>();
    if (!submission.hasMessage) {
      return const KitFailure<void>(
        KitError(
          code: KitErrorCode.invalidConfiguration,
          message: 'Feedback message must not be empty.',
        ),
      );
    }
    try {
      await _client.submitCommunication(
        message: submission.message,
        type: submission.kind.name,
        email: submission.isReplyable ? submission.email : null,
        attachments: submission.attachments,
      );
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'submit');
    }
  }

  @override
  Future<KitResult<void>> submitRatingAndReview({
    required int rating,
    String? review,
  }) async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      await _client.submitRatingAndReview(rating: rating, review: review);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _failure<void>(error, stackTrace, 'submit_rating');
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
      message: 'FeedbackNest $providerCode failed: $error',
      providerCode: 'feedbacknest_$providerCode',
      cause: error,
      stackTrace: stackTrace,
    );
    _logger.log(
      KitLogLevel.warning,
      'FeedbackNest operation failed.',
      moduleId: moduleId,
      error: mapped,
    );
    if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
    return KitFailure<T>(mapped);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'FeedbackNest provider has not been initialized.',
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
