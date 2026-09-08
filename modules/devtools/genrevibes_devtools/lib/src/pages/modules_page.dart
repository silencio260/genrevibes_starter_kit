import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_starter_kit/genrevibes_starter_kit.dart';

/// Every registered module, its live health, and its transitions as they happen.
///
/// Every capability in the kit implements `StarterModule`, so one card covers
/// all of them with no per-capability code. The timeline matters because health
/// changes after startup — a provider degrading an hour in looks identical to
/// one that never started, unless something is watching.
class DevModulesPage extends StatefulWidget {
  /// Creates the page.
  const DevModulesPage({required this.kit, super.key});

  /// The coordinator whose modules are listed.
  final GenRevibesStarterKit kit;

  @override
  State<DevModulesPage> createState() => _DevModulesPageState();
}

class _DevModulesPageState extends State<DevModulesPage> {
  final List<_Transition> _timeline = <_Transition>[];
  final List<StreamSubscription<ModuleHealth>> _subscriptions =
      <StreamSubscription<ModuleHealth>>[];

  @override
  void initState() {
    super.initState();
    for (final module in widget.kit.modules.values) {
      _subscriptions.add(
        module.healthChanges.listen((health) {
          if (!mounted) return;
          setState(() => _timeline.insert(0, _Transition(health, DateTime.now())));
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = widget.kit.modules.values.toList()
      ..sort((a, b) => a.moduleId.compareTo(b.moduleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: <Widget>[
          Text('${modules.length} registered',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final module in modules) _ModuleCard(module: module),
          if (_timeline.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text('Health timeline',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_timeline.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final entry in _timeline.take(50))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${_time(entry.at)}  ${entry.health.moduleId} → '
                  '${entry.health.state.name}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';
}

class _Transition {
  const _Transition(this.health, this.at);
  final ModuleHealth health;
  final DateTime at;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final StarterModule module;

  @override
  Widget build(BuildContext context) {
    final health = module.health;
    final scheme = Theme.of(context).colorScheme;
    final (Color colour, IconData icon) = switch (health.state) {
      ModuleState.ready => (Colors.green.shade700, Icons.check_circle),
      ModuleState.degraded => (Colors.orange.shade800, Icons.warning),
      ModuleState.failed => (scheme.error, Icons.error),
      ModuleState.disabled => (scheme.outline, Icons.remove_circle_outline),
      ModuleState.disposed => (scheme.outline, Icons.power_settings_new),
      _ => (scheme.primary, Icons.hourglass_empty),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: colour),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    health.moduleId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Text(health.state.name,
                    style: TextStyle(fontSize: 12, color: colour)),
              ],
            ),
            if (health.provider != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('provider: ${health.provider}',
                    style: const TextStyle(fontSize: 11)),
              ),
            for (final entry in health.details.entries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${entry.key}: ${entry.value}',
                    style: const TextStyle(fontSize: 11)),
              ),
            if (health.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SelectableText(
                  '${health.error!.providerCode ?? health.error!.code.name}: '
                  '${health.error!.message}',
                  style: TextStyle(fontSize: 11, color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
