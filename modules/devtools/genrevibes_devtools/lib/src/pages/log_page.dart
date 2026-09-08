import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import '../recording_kit_logger.dart';

/// Everything the kit logged, from every module, as it happens.
///
/// Modules report through their injected `KitLogger`, which defaults to a
/// no-op, so none of this is visible at runtime unless a recording logger was
/// installed. With one, consent, ads, purchases, remote config and the rest all
/// arrive in one ordered feed with their module id attached.
class DevLogPage extends StatefulWidget {
  /// Creates the page.
  const DevLogPage({required this.logger, super.key});

  /// The logger holding the records.
  final RecordingKitLogger logger;

  @override
  State<DevLogPage> createState() => _DevLogPageState();
}

class _DevLogPageState extends State<DevLogPage> {
  StreamSubscription<KitLogRecord>? _subscription;
  KitLogLevel? _minimum;
  String _module = '';

  @override
  void initState() {
    super.initState();
    _subscription = widget.logger.added.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _passes(KitLogRecord record) {
    if (_minimum != null && record.level.index < _minimum!.index) return false;
    if (_module.isEmpty) return true;
    return (record.moduleId ?? '').toLowerCase().contains(_module.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.logger.records.reversed.where(_passes).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kit log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(widget.logger.clear),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Filter by module',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _module = value),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('all', style: TextStyle(fontSize: 11)),
                      selected: _minimum == null,
                      onSelected: (_) => setState(() => _minimum = null),
                    ),
                    for (final level in KitLogLevel.values)
                      ChoiceChip(
                        label: Text(level.name,
                            style: const TextStyle(fontSize: 11)),
                        selected: _minimum == level,
                        onSelected: (_) => setState(() => _minimum = level),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: records.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing logged yet. Exercise a capability and it will '
                  'appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: records.length,
              itemBuilder: (context, index) => _RecordTile(records[index]),
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile(this.record);

  final KitLogRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = switch (record.level) {
      KitLogLevel.error => scheme.error,
      KitLogLevel.warning => Colors.orange.shade800,
      KitLogLevel.info => scheme.primary,
      KitLogLevel.debug => scheme.outline,
    };
    final at = record.at;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${at.hour.toString().padLeft(2, '0')}:'
                '${at.minute.toString().padLeft(2, '0')}:'
                '${at.second.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 6),
              Text(record.level.name,
                  style: TextStyle(fontSize: 10, color: colour)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  record.moduleId ?? '—',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SelectableText(record.message,
              style: const TextStyle(fontSize: 12)),
          if (record.error != null)
            SelectableText('${record.error}',
                style: TextStyle(fontSize: 11, color: colour)),
          if (record.fields.isNotEmpty)
            Text('${record.fields}',
                style: const TextStyle(fontSize: 10)),
          const Divider(height: 10),
        ],
      ),
    );
  }
}
