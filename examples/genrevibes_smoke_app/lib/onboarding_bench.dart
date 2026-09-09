import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_onboarding/genrevibes_onboarding.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:genrevibes_storage_shared_preferences/genrevibes_storage_shared_preferences.dart';

/// Exercises onboarding for real, rather than proving it compiles.
///
/// The rest of this app registers adapters to show the native graph starts.
/// This screen runs one: it initializes an [OnboardingController] over real
/// device storage, shows [OnboardingView] when the flag says the user is new,
/// and persists completion.
///
/// The behaviour worth checking here is the one that is invisible in a unit
/// test and expensive to get wrong in production — that completion **survives a
/// restart**. Kill the app after finishing the flow and reopen it; onboarding
/// must not appear again. Reset puts it back so the run is repeatable.
///
/// It also demonstrates the legacy-key adoption every app in the portfolio
/// needs when it adopts this module: the store is wrapped in a
/// [MigratingKeyValueStore] seeded with [OnboardingKeys.legacyKeys], so a user
/// who finished onboarding under the old `has_seen_onboarding` key is not shown
/// it a second time on the release that adopts the kit.
class OnboardingBench extends StatefulWidget {
  /// Creates the bench.
  const OnboardingBench({super.key});

  @override
  State<OnboardingBench> createState() => _OnboardingBenchState();
}

class _OnboardingBenchState extends State<OnboardingBench> {
  late final KeyValueStore _store = MigratingKeyValueStore(
    delegate: SharedPreferencesKeyValueStore(),
    legacyKeys: OnboardingKeys.legacyKeys,
    removeLegacyOnRead: false,
  );
  late final OnboardingController _controller =
      OnboardingController(store: _store);

  KitResult<void>? _startup;
  bool _showingFlow = false;
  String? _rawStoredValue;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final result = await _controller.initialize();
    await _readRaw();
    if (mounted) setState(() => _startup = result);
  }

  /// Reads the persisted flag directly, so the screen shows what is on disk
  /// rather than only what the controller believes.
  Future<void> _readRaw() async {
    final stored = await _store.getBool(OnboardingKeys.completed);
    _rawStoredValue = stored.fold(
      onSuccess: (value) => value?.toString() ?? '(absent)',
      onFailure: (error) => 'unreadable: ${error.code.name}',
    );
  }

  Future<void> _complete() async {
    await _controller.complete();
    await _readRaw();
    if (mounted) setState(() => _showingFlow = false);
  }

  Future<void> _reset() async {
    await _controller.reset();
    await _readRaw();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_showingFlow) {
      return OnboardingView(
        pages: _pages,
        onCompleted: _complete,
        onSkipped: _complete,
      );
    }

    final startup = _startup;
    final health = _controller.health;

    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Text(
            'Finish the flow, then fully close and reopen the app. Onboarding '
            'must not appear again. Reset makes the run repeatable.',
          ),
          const Divider(height: 32),
          _Fact('Module state', health.state.name),
          _Fact(
            'Initialization',
            startup == null
                ? 'running'
                : startup.fold(
                    onSuccess: (_) => 'ok',
                    onFailure: (error) => 'failed: ${error.message}',
                  ),
          ),
          _Fact('controller.isCompleted', '${_controller.isCompleted}'),
          _Fact('Stored value', _rawStoredValue ?? 'reading'),
          _Fact('Storage key', OnboardingKeys.completed),
          _Fact(
            'Adopts legacy key',
            OnboardingKeys.legacyKeys[OnboardingKeys.completed] ?? 'none',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: startup == null
                ? null
                : () => setState(() => _showingFlow = true),
            child: Text(
              _controller.isCompleted
                  ? 'Show onboarding anyway'
                  : 'Start onboarding',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: startup == null ? null : _reset,
            child: const Text('Reset completion'),
          ),
        ],
      ),
    );
  }

  static final _pages = <OnboardingPage>[
    OnboardingPage(
      title: 'Standard template',
      description:
          'Artwork, title and description. Colours come from the ambient '
          'theme, which is what lets one template serve a whole portfolio.',
      artwork: (context) => Icon(
        Icons.auto_awesome,
        size: 96,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
    const OnboardingPage(
      title: 'Minimal template',
      description: 'Title and description only, for a page with no artwork.',
      template: OnboardingTemplate.minimal,
    ),
    const OnboardingPage(
      title: 'Completion persists',
      description:
          'Finishing writes the flag through the store. Restart the app to '
          'prove it survives, which is the failure a unit test cannot catch.',
    ),
  ];
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 150,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
