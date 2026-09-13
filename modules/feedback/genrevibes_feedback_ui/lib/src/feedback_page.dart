import 'dart:async';
import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';

import 'feedback_page_options.dart';

/// Opens the feedback page and returns whether the message was sent.
Future<bool> openFeedbackPage(
  BuildContext context, {
  required FeedbackProvider provider,
  FeedbackKind kind = FeedbackKind.feedback,
  FeedbackPageLabels? labels,
  FeedbackPageTheme theme = const FeedbackPageTheme(),
  FeedbackScreenshotPicker? pickScreenshot,
  bool? requireEmail,
  int maxScreenshots = 1,
  int maxAttachmentBytes = 10 * 1024 * 1024,
  Duration submissionTimeout = const Duration(seconds: 30),
  Widget Function(Widget)? protectContent,
  Map<String, String> metadata = const <String, String>{},
  void Function(FeedbackSubmission submission, KitResult<void> result)?
      onSubmitted,
}) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) {
        final page = FeedbackPage(
          provider: provider,
          kind: kind,
          labels: labels,
          theme: theme,
          pickScreenshot: pickScreenshot,
          requireEmail: requireEmail,
          maxScreenshots: maxScreenshots,
          maxAttachmentBytes: maxAttachmentBytes,
          submissionTimeout: submissionTimeout,
          metadata: metadata,
          onSubmitted: onSubmitted,
        );
        return protectContent?.call(page) ?? page;
      },
    ),
  );
  return sent ?? false;
}

/// The feedback or contact page: email, message and optional screenshots.
///
/// Pops with whether the message was sent. [openFeedbackPage] pushes it.
class FeedbackPage extends StatefulWidget {
  /// Creates the page.
  const FeedbackPage({
    required this.provider,
    super.key,
    this.kind = FeedbackKind.feedback,
    this.labels,
    this.theme = const FeedbackPageTheme(),
    this.pickScreenshot,
    this.requireEmail,
    this.maxScreenshots = 1,
    this.maxAttachmentBytes = 10 * 1024 * 1024,
    this.submissionTimeout = const Duration(seconds: 30),
    this.metadata = const <String, String>{},
    this.onSubmitted,
  });

  /// Sends the submission.
  final FeedbackProvider provider;

  /// Feedback or a support request.
  final FeedbackKind kind;

  /// Text. Null uses [FeedbackPageLabels.forKind].
  final FeedbackPageLabels? labels;

  /// Colors and shape.
  final FeedbackPageTheme theme;

  /// Picks a screenshot. Null hides screenshots.
  final FeedbackScreenshotPicker? pickScreenshot;

  /// Whether an email is required. Null requires one for a contact request.
  final bool? requireEmail;

  /// The most screenshots the user can attach.
  final int maxScreenshots;
  final int maxAttachmentBytes;
  final Duration submissionTimeout;

  /// Non-personal context passed to the provider.
  final Map<String, String> metadata;

  /// Every send attempt, with its result.
  final void Function(FeedbackSubmission submission, KitResult<void> result)?
      onSubmitted;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final List<FeedbackAttachment> _attachments = <FeedbackAttachment>[];
  bool _sending = false;
  bool _picking = false;
  bool _sent = false;
  String? _error;

  FeedbackPageLabels get _labels =>
      widget.labels ?? FeedbackPageLabels.forKind(widget.kind);

  bool get _requireEmail =>
      widget.requireEmail ?? widget.kind == FeedbackKind.contact;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return _requireEmail ? _labels.emailRequired : null;
    return _emailPattern.hasMatch(email) ? null : _labels.emailInvalid;
  }

  Future<void> _addScreenshot() async {
    final pick = widget.pickScreenshot;
    if (pick == null ||
        _picking ||
        _sending ||
        _sent ||
        _attachments.length >= widget.maxScreenshots) {
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await pick();
      if (picked == null || !mounted || _sending || _sent) return;
      if (_attachments.length >= widget.maxScreenshots ||
          picked.sizeInBytes > widget.maxAttachmentBytes) {
        setState(() => _error = _labels.attachmentTooLarge);
        return;
      }
      setState(() {
        _attachments.add(picked);
        _error = null;
      });
    } on Object {
      if (mounted) setState(() => _error = _labels.screenshotFailed);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_sending || _sent) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final submission = FeedbackSubmission(
      message: _message.text.trim(),
      kind: widget.kind,
      email: email.isEmpty ? null : email,
      attachments: List.of(_attachments),
      metadata: widget.metadata,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    KitResult<void> result;
    try {
      result = await widget.provider
          .submit(submission)
          .timeout(widget.submissionTimeout);
    } on Object catch (error, stack) {
      result = KitFailure<void>(KitError(
          code: error is TimeoutException
              ? KitErrorCode.timeout
              : KitErrorCode.provider,
          message: 'Feedback submission could not be confirmed.',
          cause: error,
          stackTrace: stack));
    }
    if (!mounted) return;
    // User callbacks cannot leave the page stuck in its sending state.
    setState(() {
      _sending = false;
      _sent = result.isSuccess;
      _error = result.fold(
          onSuccess: (_) => null,
          onFailure: (error) => error.code == KitErrorCode.timeout
              ? _labels.sendUnconfirmed
              : _labels.sendFailed);
    });
    try {
      widget.onSubmitted?.call(submission, result);
    } on Object {/* Reporting must not change submission success. */}
  }

  /// Leaves with whether the message was sent. Not while it is sending.
  void _leave() {
    if (_sending) return;
    Navigator.of(context).pop(_sent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = theme.accentColor ?? Theme.of(context).colorScheme.primary;
    final foreground = theme.appBarForegroundColor;
    final titleStyle = theme.appBarTitleStyle;
    return PopScope<bool>(
      // Back returns whether the message was sent, and waits while it sends.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarColor,
          foregroundColor: foreground,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: theme.centerTitle,
          // A title style without a color would otherwise be drawn in the
          // default text color, not the app bar's.
          titleTextStyle: titleStyle?.color == null && foreground != null
              ? titleStyle?.copyWith(color: foreground)
              : titleStyle,
          title: Text(_labels.title),
        ),
        // The scaffold makes room for the keyboard and the form scrolls in the
        // space left, so every field and the send button stay reachable.
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _sent ? _success(accent) : _form(accent),
          ),
        ),
      ),
    );
  }

  Widget _form(Color accent) {
    final labels = _labels;
    final theme = widget.theme;
    final pickScreenshot = widget.pickScreenshot;
    final error = _error;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            labels.subtitle,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _label(
            _requireEmail
                ? labels.emailLabel
                : '${labels.emailLabel} (${labels.optional})',
          ),
          TextFormField(
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: _decoration(labels.emailHint, accent),
            validator: _validateEmail,
          ),
          const SizedBox(height: 20),
          _label(labels.messageLabel),
          TextFormField(
            controller: _message,
            enabled: !_sending,
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(labels.messageHint, accent),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? labels.messageRequired : null,
          ),
          if (pickScreenshot != null) ...<Widget>[
            const SizedBox(height: 20),
            _label('${labels.screenshotLabel} (${labels.optional})'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _attachments.length; i++)
                  _Thumbnail(
                    attachment: _attachments[i],
                    removeLabel: labels.removeScreenshot,
                    onRemove: _sending
                        ? null
                        : () => setState(() => _attachments.removeAt(i)),
                  ),
                if (_attachments.length < widget.maxScreenshots)
                  OutlinedButton.icon(
                    onPressed: _sending || _picking ? null : _addScreenshot,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(labels.addScreenshot),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: accent.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(theme.cornerRadius),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _button(
            accent: accent,
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(labels.submit),
          ),
        ],
      ),
    );
  }

  Widget _success(Color accent) {
    final labels = _labels;
    final theme = widget.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: accent, size: 40),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          labels.successTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          labels.successMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        _button(accent: accent, onPressed: _leave, child: Text(labels.done)),
      ],
    );
  }

  Widget _button({
    required Color accent,
    required VoidCallback? onPressed,
    required Widget child,
  }) =>
      SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            // While sending, the spinner stays on the accent color.
            disabledBackgroundColor: accent.withValues(alpha: 0.7),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.theme.cornerRadius),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: widget.theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  InputDecoration _decoration(String hint, Color accent) {
    final error = Theme.of(context).colorScheme.error;
    final radius = BorderRadius.circular(widget.theme.cornerRadius);
    OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: side);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: widget.theme.secondaryTextColor),
      filled: true,
      fillColor: widget.theme.fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(),
      enabledBorder: border(),
      disabledBorder: border(),
      focusedBorder: border(BorderSide(color: accent, width: 1.5)),
      errorBorder: border(BorderSide(color: error)),
      focusedErrorBorder: border(BorderSide(color: error, width: 1.5)),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.attachment,
    required this.removeLabel,
    required this.onRemove,
  });

  final FeedbackAttachment attachment;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                attachment.bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFFE0E0E0)),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
