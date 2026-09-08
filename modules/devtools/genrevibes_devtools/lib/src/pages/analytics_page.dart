import 'package:flutter/material.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';

import '../dev_analytics_catalogue.dart';

/// Fires each analytics event on its own, and shows where it actually landed.
///
/// One row per event. Pressing a row sends that event and renders the delivery
/// report **in that row**: which sinks accepted it, which rejected it and why,
/// and whether consent suppressed it entirely. Expanding a row exposes the
/// event's parameters as editable fields, pre-filled with realistic values.
class DevAnalyticsPage extends StatefulWidget {
  /// Creates the page.
  const DevAnalyticsPage({
    required this.pipeline,
    required this.catalogue,
    super.key,
  });

  /// The pipeline under test.
  final AnalyticsPipeline pipeline;

  /// Every event this application can emit.
  final DevAnalyticsCatalogue catalogue;

  @override
  State<DevAnalyticsPage> createState() => _DevAnalyticsPageState();
}

class _DevAnalyticsPageState extends State<DevAnalyticsPage> {
  String _filter = '';

  List<DevEventSpec> get _visible {
    final needle = _filter.trim().toLowerCase();
    if (needle.isEmpty) return widget.catalogue.events;
    return widget.catalogue.events
        .where((event) =>
            event.name.toLowerCase().contains(needle) ||
            (event.description ?? '').toLowerCase().contains(needle))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final events = _visible;
    final consent = widget.pipeline.consent;
    final sinks = widget.pipeline.sinks.map((sink) => sink.sinkId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: <Widget>[
                _ConsentBanner(consent: consent, sinks: sinks),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Filter ${widget.catalogue.events.length} events',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ],
            ),
          ),
        ),
      ),
      body: events.isEmpty
          ? const Center(child: Text('No event matches that filter.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: events.length,
              itemBuilder: (context, index) => _EventRow(
                key: ValueKey<String>(events[index].name),
                spec: events[index],
                pipeline: widget.pipeline,
                alwaysAttached: widget.catalogue.alwaysAttached,
              ),
            ),
    );
  }
}

class _ConsentBanner extends StatelessWidget {
  const _ConsentBanner({required this.consent, required this.sinks});

  final AnalyticsConsent consent;
  final List<String> sinks;

  @override
  Widget build(BuildContext context) {
    final granted = consent == AnalyticsConsent.granted;
    final colour = granted ? Colors.green.shade700 : Colors.orange.shade800;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        granted
            ? 'Consent granted · delivering to ${sinks.join(", ")}'
            : 'Consent is ${consent.name} — every event will be suppressed '
                'before it reaches a sink.',
        style: TextStyle(fontSize: 11, color: colour),
      ),
    );
  }
}

/// One event: fire it, edit it, see exactly where it went.
class _EventRow extends StatefulWidget {
  const _EventRow({
    required this.spec,
    required this.pipeline,
    required this.alwaysAttached,
    super.key,
  });

  final DevEventSpec spec;
  final AnalyticsPipeline pipeline;
  final Map<String, Object?> alwaysAttached;

  @override
  State<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<_EventRow> {
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
    for (final parameter in widget.spec.parameters)
      parameter.name: TextEditingController(text: '${parameter.example}'),
  };
  late final Map<String, bool> _booleans = <String, bool>{
    for (final parameter in widget.spec.parameters)
      if (parameter.kind == DevParamKind.boolean)
        parameter.name: parameter.example == true,
  };

  bool _expanded = false;
  bool _sending = false;
  AnalyticsDeliveryReport? _report;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _properties() {
    final properties = <String, Object?>{...widget.alwaysAttached};
    for (final parameter in widget.spec.parameters) {
      final raw = _controllers[parameter.name]?.text ?? '';
      properties[parameter.name] = switch (parameter.kind) {
        DevParamKind.text => raw,
        DevParamKind.integer => int.tryParse(raw) ?? parameter.example,
        DevParamKind.number => num.tryParse(raw) ?? parameter.example,
        DevParamKind.boolean => _booleans[parameter.name] ?? false,
      };
    }
    return properties;
  }

  Future<void> _fire() async {
    setState(() {
      _sending = true;
      _report = null;
      _error = null;
    });
    try {
      final result = await widget.pipeline
          .track(
            AnalyticsEvent(
              name: widget.spec.name,
              properties: _properties(),
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      result.fold(
        onSuccess: (report) => setState(() => _report = report),
        onFailure: (failure) => setState(
          () => _error = '${failure.code.name}: ${failure.message}',
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SelectableText(
                        spec.name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (spec.description != null)
                        Text(
                          spec.description!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (spec.parameters.isNotEmpty)
                  IconButton(
                    tooltip: '${spec.parameters.length} parameters',
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.tune,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                FilledButton.tonal(
                  onPressed: _sending ? null : _fire,
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Fire'),
                ),
              ],
            ),
          ),
          if (_expanded && spec.parameters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: <Widget>[
                  for (final parameter in spec.parameters)
                    _ParameterField(
                      parameter: parameter,
                      controller: _controllers[parameter.name],
                      value: _booleans[parameter.name],
                      onChanged: (value) =>
                          setState(() => _booleans[parameter.name] = value),
                    ),
                ],
              ),
            ),
          if (_report != null)
            _DeliveryPanel(report: _report!)
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SelectableText(
                _error!,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParameterField extends StatelessWidget {
  const _ParameterField({
    required this.parameter,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final DevParamSpec parameter;
  final TextEditingController? controller;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (parameter.kind == DevParamKind.boolean) {
      return SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(parameter.name, style: const TextStyle(fontSize: 12)),
        subtitle: parameter.description == null
            ? null
            : Text(parameter.description!,
                style: const TextStyle(fontSize: 11)),
        value: value ?? false,
        onChanged: onChanged,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: switch (parameter.kind) {
          DevParamKind.integer => TextInputType.number,
          DevParamKind.number =>
            const TextInputType.numberWithOptions(decimal: true),
          _ => TextInputType.text,
        },
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          labelText: '${parameter.name}  (${parameter.kind.name})',
          helperText: parameter.description,
          helperStyle: const TextStyle(fontSize: 10),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Where the event actually landed, sink by sink.
class _DeliveryPanel extends StatelessWidget {
  const _DeliveryPanel({required this.report});

  final AnalyticsDeliveryReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (report.suppressedByConsent) {
      return _panel(
        colour: Colors.orange.shade800,
        children: const <Widget>[
          Text(
            'Suppressed by consent. It never reached a sink, so nothing will '
            'appear in any dashboard.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    return _panel(
      colour: report.isCompleteSuccess ? Colors.green.shade700 : scheme.error,
      children: <Widget>[
        for (final sink in report.attemptedSinks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  report.successfulSinks.contains(sink)
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 14,
                  color: report.successfulSinks.contains(sink)
                      ? Colors.green.shade700
                      : scheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    report.successfulSinks.contains(sink)
                        ? sink
                        : '$sink — ${report.failures[sink]?.message ?? "failed"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (report.attemptedSinks.isEmpty)
          const Text('No sinks were attempted.',
              style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _panel({required Color colour, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
