import 'feedback_attachment.dart';
import 'feedback_kind.dart';

/// One piece of user feedback, ready to send.
final class FeedbackSubmission {
  /// Creates a submission.
  FeedbackSubmission({
    required this.message,
    this.kind = FeedbackKind.feedback,
    this.email,
    List<FeedbackAttachment> attachments = const <FeedbackAttachment>[],
    Map<String, String> metadata = const <String, String>{},
  })  : attachments = List<FeedbackAttachment>.unmodifiable(attachments),
        metadata = Map<String, String>.unmodifiable(metadata);

  /// What the user wrote.
  final String message;

  /// Whether this is feedback or a support request.
  final FeedbackKind kind;

  /// Reply address, when the user chose to supply one.
  ///
  /// Optional by design. Requiring an address suppresses feedback from users
  /// who do not want to be contacted, which is most of them.
  final String? email;

  /// Files the user attached.
  final List<FeedbackAttachment> attachments;

  /// Non-sensitive context such as app version or locale.
  ///
  /// Adapters forward this to the provider. Do not put credentials, tokens, or
  /// personal data here; it leaves the device.
  final Map<String, String> metadata;

  /// Whether the message contains anything worth sending.
  bool get hasMessage => message.trim().isNotEmpty;

  /// Whether the user can be replied to.
  bool get isReplyable => (email?.trim().isNotEmpty) ?? false;
}
