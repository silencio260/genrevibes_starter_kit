import 'dart:async';

import 'package:flutter/material.dart';

import '../recording_delivery_observer.dart';

/// Every analytics event the application emits, as it happens.
///
/// This is the in-app equivalent of Firebase's DebugView, and exists because
/// DebugView cannot be enabled from application code on Android. It also shows
/// more: events from ordinary use as well as from the bench, the outcome for
/// each sink separately, and the events a sink refused or consent suppressed —
/// none of which reach a dashboard to be seen.
class DevEventLogPage extends StatefulWidget {
  /// Creates the page.
  const DevEventLogPage({required this.observer, super.key});

  /// The observer holding the history.
  final RecordingDeliveryObserver observer;

  @override
  State<DevEventLogPage> createState() => _DevEventLogPageState();
}

class _DevEventLogPageState extends State<DevEventLogPage> {
  StreamSubscription<DeliveredEvent>? _subscription;
  bool _failuresOnly = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _subscription = widget.observer.added.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _passes(DeliveredEvent record) {
    if (_failuresOnly && record.isCompleteSuccess) return false;
    if (_filter.isEmpty) return true;
    return record.event.name.toLowerCase().contains(_filter.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.observer.events.reversed.where(_passes).toList();
    final total = widget.observer.events.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(widget.observer.clear),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: '$total captured',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Switch(
                      value: _failuresOnly,
                      onChanged: (value) =>
                          setState(() => _failuresOnly = value),
                    ),
                    const Text('Only what did not fully deliver',
                        style: TextStyle(fontSize: 11)),
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
                  'Nothing captured yet. Use the app normally, or fire an '
                  'event from the Analytics page, and it will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: records.length,
              itemBuilder: (context, index) => _EventTile(records[index]),
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.record);

  final DeliveredEvent record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final report = record.report;
    final at = record.at;
    final colour = report.suppressedByConsent
        ? Colors.orange.shade800
        : report.isCompleteSuccess
            ? Colors.green.shade700
            : scheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  record.event.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
                ),
              ),
            ],
          ),
          if (record.event.properties.isNotEmpty)
            SelectableText(
              record.event.properties.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('  '),
              style: const TextStyle(fontSize: 11),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              report.suppressedByConsent
                  ? 'suppressed before any sink'
                  : <String>[
                      for (final sink in report.attemptedSinks)
                        report.successfulSinks.contains(sink)
                            ? '✓ $sink'
                            : '✗ $sink '
                                '(${report.failures[sink]?.code.name ?? "failed"})',
                    ].join('   '),
              style: TextStyle(fontSize: 11, color: colour),
            ),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}
