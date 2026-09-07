import 'package:flutter/material.dart';

import '../model/settings_item.dart';
import '../model/settings_section.dart';
import 'settings_tile.dart';

/// How settings sections are laid out.
enum SettingsListStyle {
  /// Flat list with plain section headings.
  plain,

  /// Sections rendered as inset cards.
  grouped,
}

/// Renders settings sections.
///
/// Embeddable by design: it builds no `Scaffold` and no `AppBar`, so a host can
/// place it in its own route, a tab, a sheet, or alongside other content. A
/// widget that insists on owning the whole screen cannot be reused by an app
/// whose settings live inside a larger page.
final class SettingsList extends StatelessWidget {
  /// Creates a settings list.
  const SettingsList({
    required this.sections,
    super.key,
    this.style = SettingsListStyle.grouped,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Sections in display order. Empty sections are skipped.
  final List<SettingsSection> sections;

  /// Layout style.
  final SettingsListStyle style;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visible = sections.where((section) => !section.isEmpty).toList();
    return ListView.builder(
      padding: padding,
      itemCount: visible.length,
      itemBuilder: (context, index) => _Section(
        section: visible[index],
        style: style,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.style});

  final SettingsSection section;
  final SettingsListStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGrouped = style == SettingsListStyle.grouped;
    final title = section.title;
    final footer = section.footer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, isGrouped ? 24 : 16, 16, 8),
            child: Text(
              isGrouped ? title.toUpperCase() : title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isGrouped
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isGrouped)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(children: _rows(section.items, divided: true)),
          )
        else
          ..._rows(section.items, divided: false),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _rows(List<SettingsItem> items, {required bool divided}) {
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      rows.add(SettingsTile(item: items[index]));
      if (divided && index != items.length - 1) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }
    return rows;
  }
}
