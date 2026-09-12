import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exit_prompt.dart';
import 'exit_prompt_options.dart';

/// Asks before Back closes the app, in the style [config] resolves.
///
/// Wrap the app's root screen. Only this route's Back is intercepted, so Back
/// on any screen above it pops as usual.
class ExitGuard extends StatefulWidget {
  /// Creates a guard.
  const ExitGuard({
    required this.config,
    required this.child,
    super.key,
    this.onShown,
    this.onResult,
    this.onExit,
    this.enabled = true,
  });

  /// Built on every Back, so remote config, premium and ad eligibility are
  /// read at that moment.
  final ExitPromptConfig Function(BuildContext context) config;

  /// The root screen.
  final Widget child;

  /// When a prompt or the double-tap hint shows.
  final void Function(ExitPromptStyle style)? onShown;

  /// What the user chose, before it is acted on.
  final void Function(ExitPromptResult result)? onResult;

  /// Closes the app. Defaults to `SystemNavigator.pop`.
  final Future<void> Function()? onExit;

  /// Whether Back is intercepted.
  final bool enabled;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  DateTime? _lastBack;
  bool _prompting = false;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.enabled,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_onBack());
        },
        child: widget.child,
      );

  Future<void> _onBack() async {
    if (_prompting) return;
    final config = widget.config(context);
    final style = config.resolvedStyle;

    if (style == ExitPromptStyle.none) {
      widget.onResult?.call(
        ExitPromptResult(style: style, action: ExitPromptAction.exit),
      );
      await _exit();
      return;
    }

    if (style == ExitPromptStyle.doubleTap) {
      final now = DateTime.now();
      final last = _lastBack;
      if (last != null && now.difference(last) <= config.doubleTapWindow) {
        widget.onResult?.call(
          ExitPromptResult(style: style, action: ExitPromptAction.exit),
        );
        await _exit();
        return;
      }
      _lastBack = now;
      widget.onShown?.call(style);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(config.labels.doubleTapHint),
            duration: config.doubleTapWindow,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    _prompting = true;
    widget.onShown?.call(style);
    final ExitPromptResult result;
    try {
      result = await ExitPrompt.show(context, config);
    } finally {
      _prompting = false;
    }
    if (!mounted) return;
    widget.onResult?.call(result);
    switch (result.action) {
      case ExitPromptAction.exit:
        await _exit();
      case ExitPromptAction.feature:
        for (final feature in config.features) {
          if (feature.id == result.targetId) {
            feature.onSelected(context);
            break;
          }
        }
      case ExitPromptAction.offer:
        config.offer?.onAction(context);
      case ExitPromptAction.stay:
        break;
    }
  }

  Future<void> _exit() => (widget.onExit ?? SystemNavigator.pop)();
}
