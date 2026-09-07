import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';
import 'package:genrevibes_feedbacknest/genrevibes_feedbacknest.dart';

void main() {
  group('FeedbackNestFeedbackProvider initialization', () {
    test('fails loudly when no API key is configured', () async {
      // A provider that accepts and discards reports is worse than none: the
      // app keeps offering a form that goes nowhere.
      final provider = _provider(_FakeClient(), apiKey: '   ');

      final result = await provider.initialize();

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.invalidConfiguration,
      );
      expect(provider.health.state, ModuleState.failed);
    });

    test('becomes ready with a valid key', () async {
      final client = _FakeClient();
      final provider = _provider(client);

      expect((await provider.initialize()).isSuccess, isTrue);
      expect(provider.health.state, ModuleState.ready);
      expect(client.initializedWith, 'key-123');
    });

    test('is idempotent', () async {
      final client = _FakeClient();
      final provider = _provider(client);

      await provider.initialize();
      await provider.initialize();

      expect(client.initializeCount, 1);
    });

    test('rejects work before initialization', () async {
      final provider = _provider(_FakeClient());

      final result = await provider.submit(
        FeedbackSubmission(message: 'hello'),
      );

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });
  });

  group('FeedbackNestFeedbackProvider submission', () {
    test('sends the message, kind, and attachments', () async {
      final client = _FakeClient();
      final provider = await _ready(client);

      await provider.submit(
        FeedbackSubmission(
          message: 'the export is slow',
          kind: FeedbackKind.contact,
          email: 'a@b.com',
          attachments: <FeedbackAttachment>[
            FeedbackAttachment(
              filename: 'shot.png',
              bytes: Uint8List.fromList(<int>[1, 2]),
            ),
          ],
        ),
      );

      expect(client.lastMessage, 'the export is slow');
      expect(client.lastType, 'contact');
      expect(client.lastEmail, 'a@b.com');
      expect(client.lastAttachments, hasLength(1));
    });

    test('refuses an empty message rather than sending a blank report',
        () async {
      final provider = await _ready(_FakeClient());

      final result = await provider.submit(FeedbackSubmission(message: '  '));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('omits a blank email rather than sending whitespace', () async {
      final client = _FakeClient();
      final provider = await _ready(client);

      await provider.submit(FeedbackSubmission(message: 'x', email: '   '));

      expect(client.lastEmail, isNull);
    });

    test('a transport fault becomes a provider error and degrades health',
        () async {
      final client = _FakeClient();
      final provider = await _ready(client);
      // Fail only after a successful start, so this exercises the submit path
      // rather than the not-initialized guard.
      client.failWith = StateError('offline');

      final result = await provider.submit(FeedbackSubmission(message: 'x'));

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.providerCode),
        'feedbacknest_submit',
      );
      expect(provider.health.state, ModuleState.degraded);
    });

    test('submits a rating with an optional review', () async {
      final client = _FakeClient();
      final provider = await _ready(client);

      await provider.submitRatingAndReview(rating: 5, review: 'great');

      expect(client.lastRating, 5);
      expect(client.lastReview, 'great');
    });
  });

  group('FeedbackNestRatingObserver', () {
    test('captures a submitted score, including low ones', () async {
      // Low scores never reach a store, so they are invisible in store
      // analytics. Capturing them here is the point of the observer.
      final client = _FakeClient();
      final provider = await _ready(client);
      final observer = FeedbackNestRatingObserver(provider: provider);

      observer.onOutcome(RatingOutcome.submitted, rating: 2);
      await Future<void>.delayed(Duration.zero);

      expect(client.lastRating, 2);
    });

    test('ignores outcomes that carry no score', () async {
      final client = _FakeClient();
      final provider = await _ready(client);
      final observer = FeedbackNestRatingObserver(provider: provider);

      observer.onOutcome(RatingOutcome.maybeLater);
      observer.onOutcome(RatingOutcome.never);
      observer.onOutcome(RatingOutcome.submitted);
      await Future<void>.delayed(Duration.zero);

      expect(client.lastRating, isNull);
    });

    test('a reporting failure never surfaces to the caller', () async {
      final client = _FakeClient();
      final provider = await _ready(client);
      client.failWith = StateError('offline');
      final observer = FeedbackNestRatingObserver(provider: provider);

      expect(
        () => observer.onOutcome(RatingOutcome.submitted, rating: 5),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
    });
  });
}

FeedbackNestFeedbackProvider _provider(
  _FakeClient client, {
  String apiKey = 'key-123',
}) {
  return FeedbackNestFeedbackProvider(
    configuration: FeedbackNestConfiguration(apiKey: apiKey),
    client: client,
  );
}

Future<FeedbackNestFeedbackProvider> _ready(_FakeClient client) async {
  final provider = _provider(client);
  await provider.initialize();
  return provider;
}

final class _FakeClient implements FeedbackNestClient {
  Object? failWith;
  int initializeCount = 0;
  String? initializedWith;
  String? lastMessage;
  String? lastType;
  String? lastEmail;
  List<FeedbackAttachment>? lastAttachments;
  int? lastRating;
  String? lastReview;

  void _maybeThrow() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<void> initialize(String apiKey, {String userIdentifier = ''}) async {
    _maybeThrow();
    initializeCount++;
    initializedWith = apiKey;
  }

  @override
  Future<void> submitCommunication({
    required String message,
    required String type,
    String? email,
    List<FeedbackAttachment> attachments = const <FeedbackAttachment>[],
  }) async {
    _maybeThrow();
    lastMessage = message;
    lastType = type;
    lastEmail = email;
    lastAttachments = attachments;
  }

  @override
  Future<void> submitRatingAndReview({
    required int rating,
    String? review,
  }) async {
    _maybeThrow();
    lastRating = rating;
    lastReview = review;
  }
}
