import 'package:flutter/material.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';

import '../widgets/action_row.dart';
import '../widgets/dev_scaffold.dart';

/// Session replay: what this device is doing, why, and how to override it.
///
/// The "why" is the part worth having. Replay not recording looks identical
/// whether the device fell outside the rollout, the master switch is off, or
/// someone forced it off on this handset three weeks ago — and those need three
/// different responses. The controller already resolved a reason; this shows it
/// rather than inviting anyone to re-derive it.
class DevSessionReplayPage extends StatelessWidget {
  /// Creates the page.
  const DevSessionReplayPage({required this.controller, super.key});

  /// The controller that owns the decision.
  final SessionReplayController controller;

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Session replay',
      subtitle: controller.providerId ?? 'no recorder attached',
      builder: (refresh) {
        final plan = controller.plan;
        final policy = controller.policy;

        return <Widget>[
          _StateBanner(plan: plan),
          const DevHeading('Override'),
          const DevNote(
            'Beats the rollout on this device only, and is remembered across '
            'launches. Recording starts or stops as soon as you choose — '
            'nothing here needs a restart except masking.',
          ),
          _OverrideSelector(
            value: plan.manualOverride,
            onChanged: (value) async {
              await controller.setOverride(value);
              refresh();
            },
          ),
          const DevHeading('Rollout'),
          DevFact('Master switch', policy.enabled ? 'on' : 'off'),
          DevFact('Recording', '${plan.percentOfUsers}% of installs'),
          DevFact(
            'This install',
            'bucket ${plan.bucket} — '
                '${plan.inRollout ? "inside" : "outside"} the rollout',
          ),
          const DevNote(
            'The bucket is drawn once and kept, so lowering the percentage '
            'narrows the recorded group instead of picking a new one. Nobody '
            'enters the group as the number comes down.',
          ),
          ActionRow(
            label: 'Draw a new bucket',
            subtitle: 'Moves this install somewhere else in the rollout, to '
                'test a percentage without editing storage. Production never '
                'does this.',
            icon: Icons.casino,
            run: () async {
              final result = await controller.reshuffleBucket();
              refresh();
              return result;
            },
          ),
          const DevHeading('Masking'),
          DevFact('Text', plan.maskAllText ? 'masked' : 'visible'),
          DevFact('Images', plan.maskAllImages ? 'masked' : 'visible'),
          const DevNote(
            'These are the values the NEXT launch will use. The SDK builds its '
            'mask parsers when it is configured, so a change to either — from '
            'remote config or anywhere else — cannot reach a running process. '
            'Restart the app to see it applied.',
          ),
          const DevHeading('Provider'),
          ActionRow(
            label: 'Ask the SDK whether it is recording',
            subtitle: "The provider's own answer, not the plan. A disagreement "
                'means a start or stop call failed silently.',
            icon: Icons.help_outline,
            run: controller.providerIsRecording,
          ),
        ];
      },
    );
  }
}

/// What is happening right now, stated once at the top.
class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.plan});

  final SessionReplayPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = plan.recording ? Colors.green.shade700 : scheme.outline;
    final explanation = switch (plan.reason) {
      SessionReplayReason.forcedOn => 'Forced on for this device.',
      SessionReplayReason.forcedOff => 'Forced off for this device.',
      SessionReplayReason.disabledRemotely =>
        'The remote master switch is off, so nobody is being recorded.',
      SessionReplayReason.inRollout =>
        'Bucket ${plan.bucket} is inside the ${plan.percentOfUsers}% rollout.',
      SessionReplayReason.outsideRollout =>
        'Bucket ${plan.bucket} is outside the ${plan.percentOfUsers}% rollout.',
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
            plan.recording ? Icons.videocam : Icons.videocam_off,
            color: colour,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plan.recording ? 'Recording' : 'Not recording',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
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

/// Force on, follow the rollout, or force off.
class _OverrideSelector extends StatelessWidget {
  const _OverrideSelector({required this.value, required this.onChanged});

  final SessionReplayOverride value;
  final ValueChanged<SessionReplayOverride> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SegmentedButton<SessionReplayOverride>(
        segments: const <ButtonSegment<SessionReplayOverride>>[
          ButtonSegment<SessionReplayOverride>(
            value: SessionReplayOverride.forceOff,
            icon: Icon(Icons.videocam_off, size: 16),
            label: Text('Off', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment<SessionReplayOverride>(
            value: SessionReplayOverride.followRemote,
            icon: Icon(Icons.cloud_queue, size: 16),
            label: Text('Rollout', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment<SessionReplayOverride>(
            value: SessionReplayOverride.forceOn,
            icon: Icon(Icons.videocam, size: 16),
            label: Text('On', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: <SessionReplayOverride>{value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}
