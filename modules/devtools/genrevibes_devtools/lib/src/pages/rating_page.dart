import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import '../dev_rating_tools.dart';
import '../offset_kit_clock.dart';
import '../widgets/action_row.dart';
import '../widgets/dev_scaffold.dart';

/// Rating: the stored history, why the next ask is or isn't allowed, and ways
/// to ask now instead of waiting days.
///
/// Everything here runs on the app's live coordinator and store adapter, and
/// [tools] runs the app's own prompt, so a result here is what a user gets.
///
/// The history and install source are read into state once and re-read only
/// after an action or a refresh, keeping the last values on screen meanwhile.
/// Reading them inside `build` made every rebuild (an action, a scroll that
/// recycles a row) flash back to a placeholder and jump the layout.
class DevRatingPage extends StatefulWidget {
  /// Creates the page.
  const DevRatingPage({
    required this.controller,
    super.key,
    this.storeReview,
    this.tools,
    this.clock,
  });

  /// Rating coordinator.
  final RatingCoordinator controller;

  /// Store review adapter.
  final StoreReviewProvider? storeReview;

  /// The app's prompt and counters.
  final DevRatingTools? tools;

  /// The coordinator's clock, when the app made it shiftable.
  final OffsetKitClock? clock;

  @override
  State<DevRatingPage> createState() => _DevRatingPageState();
}

class _DevRatingPageState extends State<DevRatingPage> {
  KitResult<RatingSnapshot>? _snapshot;
  _Installer? _installer;

  List<String> get _triggers => widget.tools?.triggers ?? const <String>[];

  @override
  void initState() {
    super.initState();
    _reload();
    final readInstaller = widget.tools?.installSource;
    if (readInstaller != null) {
      readInstaller().then(
        (source) {
          if (mounted) setState(() => _installer = _Installer(source));
        },
        onError: (Object _) {
          if (mounted) setState(() => _installer = const _Installer(null));
        },
      );
    }
  }

  /// Re-reads the history. The previous values stay up until this lands.
  Future<void> _reload() async {
    final snapshot = await widget.controller.snapshot(triggers: _triggers);
    if (mounted) setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final storeReview = widget.storeReview;
    final tools = widget.tools;
    final clock = widget.clock;
    final triggers = _triggers;
    // Actions call this after they change something.
    void refresh() => _reload();
    return DevScaffold(
      title: 'Rating',
      subtitle: storeReview?.providerId,
      onRefresh: _reload,
      builder: (_) => <Widget>[
        DevFact('Service', controller.health.state.name),
        if (tools?.installSource != null) _InstallSource(installer: _installer),
        _History(snapshot: _snapshot, clock: clock),
        const DevHeading('Ask'),
        if (tools?.askNow != null)
          ActionRow(
            label: 'Ask now',
            subtitle: 'The app\'s real ask, skipping the timing rules. Records '
                'the ask and the answer, like a real one. An opt-out still '
                'blocks it.',
            icon: Icons.play_arrow,
            timeout: const Duration(minutes: 5),
            run: () async {
              final result = await tools!.askNow!(context);
              refresh();
              return result;
            },
          ),
        if (tools?.previewPrompt != null)
          ActionRow(
            label: 'Preview the prompt',
            subtitle: 'Shows the app\'s prompt. Records nothing.',
            icon: Icons.visibility_outlined,
            timeout: const Duration(minutes: 5),
            run: () => tools!.previewPrompt!(context),
          ),
        if (storeReview != null) ...<Widget>[
          ActionRow(
            label: 'Can the store sheet show?',
            icon: Icons.help_outline,
            run: () => storeReview.isAvailable(),
          ),
          ActionRow(
            label: 'Request the store sheet',
            subtitle: 'Records nothing. "ok" means the store took the request, '
                'not that the sheet appeared: the store rations it and '
                'never shows it on a side-loaded build.',
            icon: Icons.reviews_outlined,
            timeout: const Duration(seconds: 30),
            run: () => storeReview.requestReview(),
          ),
          ActionRow(
            label: 'Open the store listing',
            icon: Icons.open_in_new,
            run: () => storeReview.openStoreListing(),
          ),
        ],
        if (tools == null)
          const DevNote('Pass DevRatingTools to the host to ask with the '
              'app\'s own prompt from here.'),
        if (clock != null) ...<Widget>[
          const DevHeading('Clock'),
          const DevNote('Moves only the rating coordinator\'s clock, in '
              'memory. Restarting the app returns to real time.'),
          for (final step in const <Duration>[
            Duration(hours: 1),
            Duration(days: 1),
            Duration(days: 2),
            Duration(days: 7),
          ])
            ActionRow(
              label: 'Forward ${_span(step)}',
              icon: Icons.fast_forward,
              run: () async {
                clock.advance(step);
                refresh();
                return 'shifted ${_span(clock.offset)}';
              },
            ),
          ActionRow(
            label: 'Back to real time',
            icon: Icons.schedule,
            run: () async {
              clock.reset();
              refresh();
              return 'real time';
            },
          ),
        ],
        const DevHeading('History'),
        ActionRow(
          label: 'Count an app open',
          icon: Icons.login,
          run: () async {
            final result = await controller.recordAppOpen();
            refresh();
            return result.map((opens) => 'app opens now $opens');
          },
        ),
        ActionRow(
          label: 'Reset prompt history',
          subtitle: 'Clears the opt-out, the last ask and the app opens. '
              'Keeps the install date and the counters.',
          icon: Icons.restart_alt,
          isDestructive: true,
          run: () async {
            final result = await controller.reset();
            refresh();
            return result;
          },
        ),
        if (triggers.isNotEmpty)
          ActionRow(
            label: 'Full reset',
            subtitle:
                'Prompt history and every counter (${triggers.join(', ')}), '
                'so the app\'s milestone ask can happen again.',
            icon: Icons.delete_sweep_outlined,
            isDestructive: true,
            run: () async {
              final result = await controller.reset(triggers: triggers);
              refresh();
              return result;
            },
          ),
      ],
    );
  }
}

/// Renders the last snapshot read; it never reads anything itself.
class _History extends StatelessWidget {
  const _History({required this.snapshot, required this.clock});

  final KitResult<RatingSnapshot>? snapshot;
  final OffsetKitClock? clock;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (snapshot == null) return const DevFact('History', 'reading…');
    return snapshot.fold(
      onFailure: (error) => DevFact('History', 'unreadable: $error'),
      onSuccess: (s) {
        final now = s.now;
        final shift = clock?.offset ?? Duration.zero;
        final eligibleFrom = s.eligibleFrom;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const DevHeading('Next ask'),
            DevFact(
              'Decision',
              s.decision.isAllowed
                  ? 'allowed'
                  : 'blocked: ${s.decision.blockReason!.name}',
            ),
            DevFact(
              'Time rules allow it',
              eligibleFrom == null
                  ? (s.optedOut ? 'never (opted out)' : 'no install date')
                  : eligibleFrom.isAfter(now)
                      ? _when(eligibleFrom, now)
                      : 'now',
            ),
            DevFact(
              'App opens',
              '${s.appOpens} of ${s.criteria.minimumAppOpens}'
                  '${s.appOpensMissing > 0 ? ' (${s.appOpensMissing} to go)' : ''}',
            ),
            if (shift != Duration.zero)
              DevFact('Clock', 'shifted ${_span(shift)} ahead'),
            const DevHeading('Stored'),
            DevFact('Installed', _when(s.installedAt, now)),
            DevFact('Last ask', _when(s.lastPromptedAt, now)),
            DevFact('Opted out', s.optedOut ? 'yes' : 'no'),
            for (final entry in s.triggers.entries)
              DevFact('Counter ${entry.key}', '${entry.value}'),
            const DevHeading('Rules'),
            DevFact('Installed for', _span(s.criteria.minimumInstallAge)),
            DevFact('App opens', '${s.criteria.minimumAppOpens}'),
            DevFact('Between asks',
                _span(s.criteria.minimumIntervalBetweenPrompts)),
            DevFact('"Maybe later" waits', _span(s.criteria.snooze)),
          ],
        );
      },
    );
  }
}

/// Which store installed the build; `source` is `null` when side-loaded.
final class _Installer {
  const _Installer(this.source);

  final String? source;
}

class _InstallSource extends StatelessWidget {
  const _InstallSource({required this.installer});

  /// `null` until the read lands.
  final _Installer? installer;

  static const _stores = <String>{
    'com.android.vending',
    'com.apple.AppStore',
    'com.apple.TestFlight',
  };

  @override
  Widget build(BuildContext context) {
    final installer = this.installer;
    if (installer == null) return const DevFact('Installed by', 'reading…');
    final source = installer.source;
    final fromStore = source != null && _stores.contains(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DevFact('Installed by', source ?? 'side-loaded'),
        if (!fromStore && defaultTargetPlatform == TargetPlatform.android)
          const DevNote('Not installed from Google Play, so the store '
              'review sheet never appears on this install. Requests '
              'still report ok. Use the internal testing track or '
              'internal app sharing to see it; the app\'s own prompt '
              'works anywhere.'),
      ],
    );
  }
}

String _when(DateTime? moment, DateTime now) {
  if (moment == null) return 'never';
  final local = moment.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
  final gap = moment.difference(now);
  return gap.isNegative
      ? '$stamp (${_span(-gap)} ago)'
      : '$stamp (in ${_span(gap)})';
}

String _span(Duration span) {
  if (span.inDays >= 1) {
    final hours = span.inHours % 24;
    return hours == 0 ? '${span.inDays}d' : '${span.inDays}d ${hours}h';
  }
  if (span.inHours >= 1) return '${span.inHours}h ${span.inMinutes % 60}m';
  return '${span.inMinutes}m';
}
