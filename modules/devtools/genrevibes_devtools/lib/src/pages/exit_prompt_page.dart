import 'package:flutter/material.dart';
import 'package:genrevibes_exit_prompt/genrevibes_exit_prompt.dart';

import '../widgets/dev_scaffold.dart';

/// Every exit prompt style, previewed with the app's own content.
///
/// Remote config decides which style users get; this shows each one without
/// changing it. Nothing here closes the app: Exit is reported, not performed.
class DevExitPromptPage extends StatefulWidget {
  /// Creates the page.
  const DevExitPromptPage({required this.config, super.key});

  /// The app's prompt for a style and Exit button.
  final ExitPromptConfig Function(
    BuildContext context,
    ExitPromptStyle style,
    ExitButtonEmphasis exitButton,
  ) config;

  @override
  State<DevExitPromptPage> createState() => _DevExitPromptPageState();
}

class _DevExitPromptPageState extends State<DevExitPromptPage> {
  ExitButtonEmphasis _exitButton = ExitButtonEmphasis.standard;
  String? _last;

  Future<void> _preview(ExitPromptStyle style) async {
    final config = widget.config(context, style, _exitButton);
    final resolved = config.resolvedStyle;
    if (resolved == ExitPromptStyle.doubleTap ||
        resolved == ExitPromptStyle.none) {
      setState(() {
        _last = '${resolved.wireName}: nothing to show; ExitGuard handles Back';
      });
      return;
    }
    final result = await ExitPrompt.show(context, config);
    if (!mounted) return;
    final target = result.targetId == null ? '' : ' (${result.targetId})';
    setState(() {
      _last = '${result.style.wireName} → ${result.action.name}$target';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DevScaffold(
      title: 'Exit prompt',
      subtitle: 'Every style, without remote config',
      builder: (refresh) => <Widget>[
        const DevNote(
          'Shows the app\'s own prompt in each style. Users get the one '
          'exit_prompt_style names; a style missing what it needs, such as an '
          'ad for a premium user, falls back. Exit is reported here, not '
          'performed.',
        ),
        const DevHeading('Exit button'),
        SegmentedButton<ExitButtonEmphasis>(
          segments: <ButtonSegment<ExitButtonEmphasis>>[
            for (final emphasis in ExitButtonEmphasis.values)
              ButtonSegment<ExitButtonEmphasis>(
                value: emphasis,
                label: Text(emphasis.wireName),
              ),
          ],
          selected: <ExitButtonEmphasis>{_exitButton},
          onSelectionChanged: (selection) =>
              setState(() => _exitButton = selection.first),
        ),
        const DevHeading('Styles'),
        for (final style in ExitPromptStyle.values)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(style.wireName),
              subtitle: Text(
                widget.config(context, style, _exitButton).resolvedStyle ==
                        style
                    ? 'shows as configured'
                    : 'falls back to '
                        '${widget.config(context, style, _exitButton).resolvedStyle.wireName}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _preview(style),
            ),
          ),
        if (_last != null) ...<Widget>[
          const DevHeading('Last result'),
          DevFact('Result', _last!),
        ],
      ],
    );
  }
}
