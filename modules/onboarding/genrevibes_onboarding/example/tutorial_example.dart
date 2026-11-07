import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_onboarding/genrevibes_onboarding.dart';

/// Embed as a MaterialApp home to explore two independent tutorials.
/// Defaults to isolated memory; inject a KeyValueTutorialProgressStore to save.
/// English labels are example content; real apps supply localized strings.
class TutorialExample extends StatefulWidget {
  const TutorialExample({super.key, this.store});
  final TutorialProgressStore? store;

  @override
  State<TutorialExample> createState() => _TutorialExampleState();
}

class _TutorialExampleState extends State<TutorialExample> {
  late final TutorialProgressStore _store =
      widget.store ?? MemoryTutorialProgressStore();
  late final _editor = TutorialController(
      tutorialId: 'editor_basics',
      stepIds: const ['add', 'export', 'ready'],
      store: _store);
  late final _search = TutorialController(
      tutorialId: 'search_basics',
      stepIds: const ['query', 'ready'],
      store: _store);
  final _addKey = GlobalKey();
  final _exportKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _focus = FocusNode();
  TutorialController? _selected;
  bool _starting = false;
  int _paragraphs = 0;
  String _query = '';

  void _error(KitError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save tutorial progress. Please try again.')));
  }

  Future<void> _begin(TutorialController controller,
      {bool replay = false}) async {
    if (_starting || (_selected?.isBusy ?? false)) return;
    _starting = true;
    try {
      final initialized = await controller.initialize();
      if (!mounted) return;
      if (initialized case KitFailure(:final error)) {
        _error(error);
        return;
      }
      // Host chooses which tutorial owns this surface; their saved state is
      // independent. Stop the old one without completing it.
      if (_selected != controller) _selected?.stop();
      setState(() => _selected = controller);
      final result =
          replay ? await controller.replay() : await controller.start();
      if (result case KitFailure(:final error)) _error(error);
    } finally {
      _starting = false;
    }
  }

  Future<void> _add() async {
    setState(() => _paragraphs++);
    final result = await _editor.advanceFrom('add');
    if (result case KitFailure(:final error)) _error(error);
  }

  Future<void> _export() async {
    // A real app would wait for its export operation to succeed here.
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Export preview'),
              content: Text('$_paragraphs paragraphs are ready.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Return to editor'))
              ],
            ));
    if (!mounted) return;
    final result = await _editor.advanceFrom('export');
    if (result case KitFailure(:final error)) _error(error);
  }

  List<TutorialStep> get _editorSteps => [
        TutorialStep(
            id: 'add',
            title: 'Add content',
            body:
                'Tap Add to create a paragraph, or choose Next to look around first.',
            target: TutorialTarget.key(_addKey),
            interaction: TutorialInteraction.targetOnly,
            primaryLabel: 'Add a paragraph',
            onPrimary: _add,
            showNext: true),
        TutorialStep(
            id: 'export',
            title: 'Export your document',
            body: 'Open the export preview, then return here.',
            target: TutorialTarget.key(_exportKey),
            interaction: TutorialInteraction.targetOnly,
            primaryLabel: 'Preview export',
            onPrimary: _export,
            showNext: true),
        const TutorialStep(
            id: 'ready',
            title: 'Editor ready',
            body: 'You can replay this guide without resetting Search.',
            allowSkip: false),
      ];

  List<TutorialStep> get _searchSteps => [
        TutorialStep(
            id: 'query',
            title: 'Find a document',
            body:
                'Type a search query. This step stays interactive until text is entered.',
            target: TutorialTarget.key(_searchKey),
            interaction: TutorialInteraction.targetOnly,
            primaryLabel: 'Focus search',
            onPrimary: _focus.requestFocus,
            showNext: true,
            placement: TutorialCardPlacement.bottom),
        const TutorialStep(
            id: 'ready',
            title: 'Search ready',
            body: 'This tutorial has its own saved progress.',
            allowSkip: false),
      ];

  @override
  void dispose() {
    _editor.dispose();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reusable tutorials')),
        body: Stack(children: [
          ListView(padding: const EdgeInsets.all(20), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              TextButton(
                  onPressed: () => _begin(_editor),
                  child: const Text('Resume editor guide')),
              TextButton(
                  onPressed: () => _begin(_editor, replay: true),
                  child: const Text('Replay editor guide')),
              TextButton(
                  onPressed: () => _begin(_search, replay: true),
                  child: const Text('Search guide')),
            ]),
            TextField(
                key: _searchKey,
                focusNode: _focus,
                decoration: const InputDecoration(labelText: 'Search'),
                onChanged: (value) {
                  setState(() => _query = value);
                  if (value.trim().isNotEmpty) {
                    unawaited(_search.advanceFrom('query').then((result) {
                      if (result case KitFailure(:final error)) _error(error);
                    }));
                  }
                }),
            const SizedBox(height: 24),
            Text('Document preview: $_paragraphs paragraphs. Query: $_query'),
            const SizedBox(height: 24),
            FilledButton(
                key: _addKey,
                onPressed: _add,
                child: const Text('Add paragraph')),
            const SizedBox(height: 12),
            OutlinedButton(
                key: _exportKey,
                onPressed: _export,
                child: const Text('Export preview')),
          ]),
          if (_selected case final controller?)
            Positioned.fill(
                child: TutorialOverlay(
              key: ValueKey(controller.tutorialId),
              controller: controller,
              steps: controller == _editor ? _editorSteps : _searchSteps,
              labels: const TutorialLabels(
                  next: 'Next',
                  previous: 'Back',
                  skip: 'Skip guide',
                  finish: 'Done'),
              showPrevious: true,
              onError: _error,
            )),
        ]),
      );
}
