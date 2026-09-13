import 'package:flutter/material.dart';
import 'package:genrevibes_developer_access/genrevibes_developer_access.dart';

/// A hidden tap target that opens the developer passcode page.
///
/// Wrap something ordinary — a screen title. [requiredTaps] taps within
/// [window] opens the page. It does nothing at all, with no hint that it
/// exists, when access is already granted or passcode entry is locked out.
class DeveloperUnlockGesture extends StatefulWidget {
  /// Creates the target.
  const DeveloperUnlockGesture({
    required this.controller,
    required this.child,
    super.key,
    this.requiredTaps = DeveloperAccessDefaults.unlockTaps,
    this.window = const Duration(seconds: 3),
    this.theme = const DeveloperPasscodeTheme(),
    this.onGranted,
  });

  /// The controller that checks the passcode.
  final DeveloperAccessController controller;

  /// What the user sees.
  final Widget child;

  /// Taps that open the page.
  final int requiredTaps;

  /// How quickly those taps must come.
  final Duration window;

  /// Colors of the passcode page. Pass those of the screen the gesture is on.
  final DeveloperPasscodeTheme theme;

  /// Called after a correct passcode.
  final VoidCallback? onGranted;

  @override
  State<DeveloperUnlockGesture> createState() => _DeveloperUnlockGestureState();
}

class _DeveloperUnlockGestureState extends State<DeveloperUnlockGesture> {
  int _taps = 0;
  DateTime? _firstTapAt;

  Future<void> _onTap() async {
    final now = DateTime.now();
    final first = _firstTapAt;
    if (first == null || now.difference(first) > widget.window) {
      _firstTapAt = now;
      _taps = 0;
    }
    _taps++;
    if (_taps < widget.requiredTaps) return;
    _taps = 0;
    _firstTapAt = null;

    final access = widget.controller.current;
    if (access.isGranted || access.lockedOut) return;

    final outcome = await openDeveloperPasscodePage(
      context,
      controller: widget.controller,
      theme: widget.theme,
    );
    if (outcome == PasscodeOutcome.granted) widget.onGranted?.call();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: widget.child,
      );
}

/// Colors and shape of the developer passcode page.
///
/// Null values come from the app's `ThemeData`. Pass the colors of the screen
/// the unlock gesture is on, so the page looks like part of the app.
final class DeveloperPasscodeTheme {
  /// Creates a theme.
  const DeveloperPasscodeTheme({
    this.appBarColor,
    this.appBarForegroundColor,
    this.appBarTitleStyle,
    this.centerTitle,
    this.backgroundColor,
    this.accentColor,
    this.fieldColor = const Color(0xFFEEEEEE),
    this.textColor = const Color(0xFF424242),
    this.secondaryTextColor = const Color(0xFF757575),
    this.cornerRadius = 12,
  });

  /// The app bar.
  final Color? appBarColor;

  /// The title and back arrow.
  final Color? appBarForegroundColor;

  /// The title. Without a color of its own it takes [appBarForegroundColor].
  final TextStyle? appBarTitleStyle;

  /// Whether the title is centered.
  final bool? centerTitle;

  /// Behind the page.
  final Color? backgroundColor;

  /// The button, focus and the lock. Null uses the theme's primary.
  final Color? accentColor;

  /// Text field fill.
  final Color fieldColor;

  /// Headings.
  final Color textColor;

  /// The line under the heading, and hints.
  final Color secondaryTextColor;

  /// The field and button.
  final double cornerRadius;
}

/// Opens the developer passcode page.
///
/// Resolves to the last outcome, or `null` when the user goes back. A wrong
/// passcode keeps the page open; the attempt that locks entry closes it without
/// saying so.
Future<PasscodeOutcome?> openDeveloperPasscodePage(
  BuildContext context, {
  required DeveloperAccessController controller,
  DeveloperPasscodeTheme theme = const DeveloperPasscodeTheme(),
}) {
  return Navigator.of(context).push<PasscodeOutcome>(
    MaterialPageRoute<PasscodeOutcome>(
      builder: (_) =>
          DeveloperPasscodePage(controller: controller, theme: theme),
    ),
  );
}

/// The developer passcode page. [openDeveloperPasscodePage] pushes it.
class DeveloperPasscodePage extends StatefulWidget {
  /// Creates the page.
  const DeveloperPasscodePage({
    required this.controller,
    super.key,
    this.theme = const DeveloperPasscodeTheme(),
  });

  /// The controller that checks the passcode.
  final DeveloperAccessController controller;

  /// Colors and shape.
  final DeveloperPasscodeTheme theme;

  @override
  State<DeveloperPasscodePage> createState() => _DeveloperPasscodePageState();
}

class _DeveloperPasscodePageState extends State<DeveloperPasscodePage> {
  final TextEditingController _field = TextEditingController();
  bool _submitting = false;
  bool _obscured = true;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _field.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final outcome = await widget.controller.submitPasscode(_field.text);
    if (!mounted) return;
    switch (outcome) {
      case PasscodeOutcome.granted:
      case PasscodeOutcome.lockedOut:
        Navigator.of(context).pop(outcome);
      case PasscodeOutcome.incorrect:
        _field.clear();
        setState(() {
          _submitting = false;
          _error = 'Incorrect passcode';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = theme.accentColor ?? Theme.of(context).colorScheme.primary;
    final foreground = theme.appBarForegroundColor;
    final titleStyle = theme.appBarTitleStyle;
    final radius = BorderRadius.circular(theme.cornerRadius);
    final error = Theme.of(context).colorScheme.error;
    OutlineInputBorder border([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: side);

    return PopScope(
      canPop: !_submitting,
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
          title: const Text('Developer access'),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_outline, color: accent, size: 34),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter the passcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Developer tools stay unlocked until the app closes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _field,
                  autofocus: true,
                  enabled: !_submitting,
                  obscureText: _obscured,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Passcode',
                    hintStyle: TextStyle(color: theme.secondaryTextColor),
                    errorText: _error,
                    filled: true,
                    fillColor: theme.fieldColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: border(),
                    enabledBorder: border(),
                    disabledBorder: border(),
                    focusedBorder:
                        border(BorderSide(color: accent, width: 1.5)),
                    errorBorder: border(BorderSide(color: error)),
                    focusedErrorBorder:
                        border(BorderSide(color: error, width: 1.5)),
                    suffixIcon: IconButton(
                      tooltip: _obscured ? 'Show passcode' : 'Hide passcode',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: theme.secondaryTextColor,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      // While checking, the spinner stays on the accent color.
                      disabledBackgroundColor: accent.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: radius),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
