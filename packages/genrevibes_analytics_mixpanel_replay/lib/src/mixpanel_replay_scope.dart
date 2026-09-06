import 'package:flutter/widgets.dart';

import 'mixpanel_replay_controller.dart';

/// Rebuilds the root replay wrapper when controller readiness changes.
final class MixpanelReplayScope extends StatefulWidget {
  /// Creates a Mixpanel replay scope.
  const MixpanelReplayScope({
    super.key,
    required this.controller,
    required this.child,
    this.initialize = true,
  });

  /// Replay controller shared with application consent and privacy controls.
  final MixpanelReplayController controller;

  /// Application widget tree.
  final Widget child;

  /// Whether this scope initializes the controller automatically.
  final bool initialize;

  @override
  State<MixpanelReplayScope> createState() => _MixpanelReplayScopeState();
}

class _MixpanelReplayScopeState extends State<MixpanelReplayScope> {
  @override
  void initState() {
    super.initState();
    if (widget.initialize) _initialize();
  }

  Future<void> _initialize() async {
    await widget.controller.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.controller.wrap(widget.child);
  }
}
