import 'package:flutter/material.dart';
import 'package:genrevibes_developer_access/genrevibes_developer_access.dart';

/// A hidden tap target that opens the developer passcode prompt.
///
/// Wrap something ordinary — a screen title. [requiredTaps] taps within
/// [window] opens the prompt. It does nothing at all, with no hint that it
/// exists, when access is already granted or passcode entry is locked out.
class DeveloperUnlockGesture extends StatefulWidget {
  /// Creates the target.
  const DeveloperUnlockGesture({
    required this.controller,
    required this.child,
    super.key,
    this.requiredTaps = DeveloperAccessDefaults.unlockTaps,
    this.window = const Duration(seconds: 3),
    this.onGranted,
  });

  /// The controller that checks the passcode.
  final DeveloperAccessController controller;

  /// What the user sees.
  final Widget child;

  /// Taps that open the prompt.
  final int requiredTaps;

  /// How quickly those taps must come.
  final Duration window;

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

    final outcome = await showDeveloperPasscodeDialog(
      context,
      controller: widget.controller,
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

/// Prompts for the developer passcode.
///
/// Resolves to the last outcome, or `null` when dismissed. A wrong passcode
/// keeps the prompt open; the attempt that locks entry closes it without
/// saying so.
Future<PasscodeOutcome?> showDeveloperPasscodeDialog(
  BuildContext context, {
  required DeveloperAccessController controller,
}) {
  return showDialog<PasscodeOutcome>(
    context: context,
    builder: (_) => _PasscodeDialog(controller: controller),
  );
}

class _PasscodeDialog extends StatefulWidget {
  const _PasscodeDialog({required this.controller});

  final DeveloperAccessController controller;

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog> {
  final TextEditingController _field = TextEditingController();
  bool _submitting = false;
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
    return AlertDialog(
      title: const Text('Developer access'),
      content: TextField(
        controller: _field,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        decoration: InputDecoration(labelText: 'Passcode', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
