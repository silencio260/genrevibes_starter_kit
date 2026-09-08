import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

/// What happened the last time an action ran.
enum ActionPhase {
  /// Never run, or cleared.
  idle,

  /// Running now.
  running,

  /// Finished and reported success.
  succeeded,

  /// Finished and reported a failure.
  failed,

  /// Did not finish inside its budget.
  timedOut,
}

/// A single thing the bench can do, with its own result shown beside it.
///
/// Each row owns its state. That is the whole point: the previous bench kept
/// one `_busy` flag for the entire screen and printed every result into a log
/// at the bottom of a long scroll, so pressing a button appeared to do nothing
/// and one call that never settled disabled everything else permanently.
///
/// Here a running action disables only itself, its outcome appears directly
/// underneath it, and [timeout] guarantees it reports something even when the
/// vendor never calls back.
class ActionRow extends StatefulWidget {
  /// Creates an action.
  const ActionRow({
    required this.label,
    required this.run,
    super.key,
    this.subtitle,
    this.icon,
    this.timeout = const Duration(seconds: 15),
    this.isDestructive = false,
    this.trailing,
  });

  /// Button text.
  final String label;

  /// Optional explanation shown under the label.
  final String? subtitle;

  /// Optional leading icon.
  final IconData? icon;

  /// The work. Returning a [KitResult] renders its error verbatim; returning
  /// anything else renders its `toString`.
  final Future<Object?> Function() run;

  /// How long before the action is abandoned and reported as timed out.
  final Duration timeout;

  /// Renders the action in the error colour, for anything irreversible.
  final bool isDestructive;

  /// Optional widget shown at the end of the row.
  final Widget? trailing;

  @override
  State<ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<ActionRow> {
  ActionPhase _phase = ActionPhase.idle;
  String? _result;
  DateTime? _finishedAt;
  Duration? _took;

  Future<void> _invoke() async {
    if (_phase == ActionPhase.running) return;
    setState(() {
      _phase = ActionPhase.running;
      _result = null;
    });
    final started = DateTime.now();

    try {
      final outcome = await widget.run().timeout(widget.timeout);
      if (!mounted) return;
      if (outcome is KitResult) {
        outcome.fold(
          onSuccess: (value) => _finish(
            ActionPhase.succeeded,
            value == null ? 'ok' : '$value',
            started,
          ),
          onFailure: (error) => _finish(
            ActionPhase.failed,
            _describe(error),
            started,
          ),
        );
      } else {
        _finish(ActionPhase.succeeded, outcome == null ? 'ok' : '$outcome',
            started);
      }
    } on TimeoutException {
      if (!mounted) return;
      _finish(
        ActionPhase.timedOut,
        'No response within ${widget.timeout.inSeconds}s. The provider never '
        'called back; the bench is still usable.',
        started,
      );
    } on Object catch (error, stackTrace) {
      if (!mounted) return;
      _finish(ActionPhase.failed, '$error\n$stackTrace', started);
    }
  }

  /// Renders a [KitError] as its parts, not a flattened sentence.
  String _describe(KitError error) {
    final buffer = StringBuffer('${error.code.name}: ${error.message}');
    if (error.providerCode != null) {
      buffer.write('\nprovider code: ${error.providerCode}');
    }
    if (error.metadata.isNotEmpty) buffer.write('\n${error.metadata}');
    return buffer.toString();
  }

  void _finish(ActionPhase phase, String result, DateTime started) {
    setState(() {
      _phase = phase;
      _result = result;
      _finishedAt = DateTime.now();
      _took = _finishedAt!.difference(started);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _phase == ActionPhase.running;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: running ? null : _invoke,
                  icon: running
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.icon ?? Icons.play_arrow, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(widget.label,
                            style: const TextStyle(fontSize: 13)),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor:
                        widget.isDestructive ? theme.colorScheme.error : null,
                  ),
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
          if (_result != null) _ResultPanel(
            phase: _phase,
            result: _result!,
            took: _took,
            onDismiss: () => setState(() {
              _phase = ActionPhase.idle;
              _result = null;
            }),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.phase,
    required this.result,
    required this.onDismiss,
    this.took,
  });

  final ActionPhase phase;
  final String result;
  final Duration? took;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color colour, IconData icon) = switch (phase) {
      ActionPhase.succeeded => (Colors.green.shade700, Icons.check_circle),
      ActionPhase.failed => (scheme.error, Icons.error),
      ActionPhase.timedOut => (Colors.orange.shade800, Icons.timer_off),
      _ => (scheme.outline, Icons.info),
    };

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            // Selectable so ids and error text can be copied out.
            child: SelectableText(
              took == null ? result : '$result\n(${took!.inMilliseconds}ms)',
              style: TextStyle(fontSize: 12, color: colour),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 16, color: colour),
          ),
        ],
      ),
    );
  }
}
