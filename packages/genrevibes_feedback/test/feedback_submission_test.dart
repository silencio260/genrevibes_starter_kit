import 'dart:typed_data';

import 'package:genrevibes_feedback/genrevibes_feedback.dart';
import 'package:test/test.dart';

void main() {
  group('FeedbackSubmission', () {
    test('defaults to product feedback with no attachments', () {
      final submission = FeedbackSubmission(message: 'the export is slow');

      expect(submission.kind, FeedbackKind.feedback);
      expect(submission.attachments, isEmpty);
      expect(submission.metadata, isEmpty);
    });

    test('reports whether it carries a message', () {
      expect(FeedbackSubmission(message: 'hello').hasMessage, isTrue);
      expect(FeedbackSubmission(message: '   ').hasMessage, isFalse);
      expect(FeedbackSubmission(message: '').hasMessage, isFalse);
    });

    test('reports whether the user can be replied to', () {
      expect(FeedbackSubmission(message: 'x').isReplyable, isFalse);
      expect(
        FeedbackSubmission(message: 'x', email: '  ').isReplyable,
        isFalse,
      );
      expect(
        FeedbackSubmission(message: 'x', email: 'a@b.com').isReplyable,
        isTrue,
      );
    });

    test('copies its collections so a caller cannot mutate a sent report', () {
      final attachments = <FeedbackAttachment>[_attachment()];
      final metadata = <String, String>{'appVersion': '1.0.0'};
      final submission = FeedbackSubmission(
        message: 'x',
        attachments: attachments,
        metadata: metadata,
      );

      expect(() => submission.attachments.clear(), throwsUnsupportedError);
      expect(() => submission.metadata.clear(), throwsUnsupportedError);
    });

    test('distinguishes support requests from product feedback', () {
      final contact = FeedbackSubmission(
        message: 'my purchase did not restore',
        kind: FeedbackKind.contact,
      );

      expect(contact.kind, FeedbackKind.contact);
    });
  });

  group('FeedbackAttachment', () {
    test('reports its size and defaults to a binary media type', () {
      final attachment = _attachment();

      expect(attachment.sizeInBytes, 3);
      expect(attachment.mimeType, 'application/octet-stream');
    });

    test('copies its bytes so later mutation cannot alter a sent file', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final attachment = FeedbackAttachment(
        filename: 'screenshot.png',
        bytes: bytes,
      );

      bytes[0] = 99;

      expect(attachment.bytes[0], 1);
    });
  });
}

FeedbackAttachment _attachment() => FeedbackAttachment(
      filename: 'screenshot.png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
