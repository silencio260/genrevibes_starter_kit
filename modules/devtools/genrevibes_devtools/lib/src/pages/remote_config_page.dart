import 'package:flutter/material.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// Every key in the schema, with where its current value came from.
///
/// The origin is the part that matters. A value equal to its default might be
/// the default, or it might be a remote value that happens to match, and those
/// mean opposite things when a remote change appears not to have taken effect.
class DevRemoteConfigPage extends StatefulWidget {
  /// Creates the page.
  const DevRemoteConfigPage({
    required this.coordinator,
    required this.schema,
    super.key,
  });

  /// The coordinator holding the current snapshot.
  final RemoteConfigCoordinator coordinator;

  /// Every key the application declared.
  final RemoteConfigSchema schema;

  @override
  State<DevRemoteConfigPage> createState() => _DevRemoteConfigPageState();
}

class _DevRemoteConfigPageState extends State<DevRemoteConfigPage> {
  String _filter = '';
  bool _refreshing = false;
  String? _refreshResult;

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshResult = null;
    });
    try {
      final result = await widget.coordinator
          .refresh()
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      result.fold(
        onSuccess: (snapshot) => setState(
          () => _refreshResult =
              'Fetched at ${snapshot.observedAt.toIso8601String()}',
        ),
        onFailure: (error) => setState(
          () => _refreshResult = '${error.code.name}: ${error.message}',
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _refreshResult = '$error');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.coordinator.current;
    final needle = _filter.trim().toLowerCase();
    final keys = widget.schema.keys
        .where((key) => needle.isEmpty || key.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final remoteCount = widget.schema.keys
        .where((key) =>
            snapshot.originOf(key) == RemoteConfigValueOrigin.remote)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote config'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Fetch from server',
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText:
                    'Filter ${widget.schema.keys.length} keys · $remoteCount from server',
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          if (_refreshResult != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SelectableText(_refreshResult!,
                  style: const TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: keys.length,
              itemBuilder: (context, index) =>
                  _KeyRow(key_: keys[index], snapshot: snapshot),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.key_, required this.snapshot});

  final RemoteConfigKey<Object?> key_;
  final RemoteConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final origin = snapshot.originOf(key_);
    final value = snapshot.read(key_);
    final isDefault = origin == RemoteConfigValueOrigin.defaultValue;
    final colour = switch (origin) {
      RemoteConfigValueOrigin.remote => Colors.green.shade700,
      RemoteConfigValueOrigin.cache ||
      RemoteConfigValueOrigin.providerCache =>
        Colors.blue.shade700,
      RemoteConfigValueOrigin.defaultValue => Theme.of(context).colorScheme.outline,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  key_.name,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(origin.name,
                    style: TextStyle(fontSize: 10, color: colour)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SelectableText(
              isDefault
                  ? '$value   (${key_.codec.kind.name}, default)'
                  : '$value   (${key_.codec.kind.name}, default '
                      '${key_.defaultValue})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDefault ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}
