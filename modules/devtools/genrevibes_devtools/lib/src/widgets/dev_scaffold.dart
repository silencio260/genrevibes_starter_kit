import 'package:flutter/material.dart';

/// A bench page whose contents are rebuilt on demand.
///
/// State on these pages is read live from the modules rather than cached, so a
/// page needs a way to re-read after an action changes something. [builder]
/// receives a callback that does exactly that; there is no shared busy flag and
/// nothing goes stale silently.
class DevScaffold extends StatefulWidget {
  /// Creates a page.
  const DevScaffold({
    required this.title,
    required this.builder,
    super.key,
    this.subtitle,
  });

  /// App bar title.
  final String title;

  /// Optional line under the title, usually the provider id.
  final String? subtitle;

  /// Builds the body. The callback re-reads live state.
  final List<Widget> Function(VoidCallback refresh) builder;

  @override
  State<DevScaffold> createState() => _DevScaffoldState();
}

class _DevScaffoldState extends State<DevScaffold> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Re-read state',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: widget.builder(_refresh),
        ),
      ),
    );
  }
}

/// A section heading.
class DevHeading extends StatelessWidget {
  /// Creates a heading.
  const DevHeading(this.text, {super.key});

  /// The text.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

/// A read-only label and value.
class DevFact extends StatelessWidget {
  /// Creates a fact row.
  const DevFact(this.label, this.value, {super.key});

  /// What it is.
  final String label;

  /// What it currently is.
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
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
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// An explanatory note.
class DevNote extends StatelessWidget {
  /// Creates a note.
  const DevNote(this.text, {super.key});

  /// The text.
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}
