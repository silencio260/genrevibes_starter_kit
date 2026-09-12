import 'package:flutter/material.dart';
import 'package:genrevibes_system_ui/genrevibes_system_ui.dart';

import '../widgets/dev_scaffold.dart';

/// The system navigation bar: whether it shows now, why, and the developer
/// switch that shows it on every screen.
class DevNavigationBarPage extends StatelessWidget {
  /// Creates the page.
  const DevNavigationBarPage({required this.controller, super.key});

  /// The controller that owns the decision.
  final NavigationBarController controller;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Navigation bar',
      subtitle: controller.isSupported
          ? 'Android system navigation bar'
          : 'not supported on this platform',
      builder: (refresh) => <Widget>[
        StreamBuilder<NavigationBarState>(
          stream: controller.changes,
          initialData: controller.current,
          builder: (context, snapshot) =>
              _StateBanner(state: snapshot.data ?? controller.current),
        ),
        const DevHeading('Developers'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show on every screen'),
          subtitle: Text(
            controller.developerMode
                ? 'Developer access is granted on this device.'
                : 'Applies only while developer access is granted.',
            style: const TextStyle(fontSize: 11),
          ),
          value: controller.developerShowsEverywhere,
          onChanged: (value) async {
            await controller.setDeveloperShowsEverywhere(value);
            refresh();
          },
        ),
        const DevNote(
          'Remembered on this device. Turn it off to see the app the way users '
          'do: hidden, except on the screens that show it.',
        ),
        const DevHeading('Everyone else'),
        DevFact(
          'Default',
          controller.visibleByDefault ? 'shown' : 'hidden',
        ),
        DevFact(
          'Routes',
          controller.routes.isEmpty
              ? 'none'
              : controller.routes.entries
                  .map((e) => '${e.key}: ${e.value ? "shown" : "hidden"}')
                  .join('\n'),
        ),
        const DevNote(
          'A screen shows or hides the bar with NavigationBarVisibility. A '
          'dialog or sheet keeps the bar of the screen under it. Hidden, a '
          'swipe from the bottom edge shows it for a moment.',
        ),
      ],
    );
  }
}

/// What is happening right now, stated once at the top.
class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.state});

  final NavigationBarState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = state.visible ? Colors.green.shade700 : scheme.outline;
    final route = state.routeName ?? 'an unnamed route';
    final explanation = switch (state.reason) {
      NavigationBarReason.developer =>
        'Developer access is granted and "Show on every screen" is on.',
      NavigationBarReason.screen => 'The screen on top ($route) asked for it.',
      NavigationBarReason.route =>
        '$route is configured to ${state.visible ? "show" : "hide"} it.',
      NavigationBarReason.byDefault =>
        'The screen on top ($route) did not ask, so the default applies.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            state.visible ? Icons.visibility : Icons.visibility_off,
            color: colour,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.visible ? 'Shown' : 'Hidden',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colour),
                ),
                Text(explanation, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
