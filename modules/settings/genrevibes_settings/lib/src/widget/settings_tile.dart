import 'package:flutter/material.dart';

import '../model/settings_item.dart';

/// Renders a single [SettingsItem].
///
/// Exposed so a host can compose its own layout from the same rows rather than
/// being forced to use [SettingsList].
final class SettingsTile extends StatelessWidget {
  /// Creates a settings tile.
  const SettingsTile({required this.item, super.key});

  /// Row to render.
  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (item) {
      SettingsCustom(:final builder) => builder(context),
      SettingsToggle(:final value, :final onChanged) => SwitchListTile(
          value: value,
          onChanged: onChanged,
          title: Text(item.title),
          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
          secondary: _leading(theme),
        ),
      SettingsInfo(:final value) => ListTile(
          title: Text(item.title),
          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
          leading: _leading(theme),
          trailing: Text(value, style: theme.textTheme.bodyMedium),
          enabled: false,
        ),
      SettingsAction(:final onTap, :final isDestructive) => ListTile(
          title: Text(
            item.title,
            style: isDestructive
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
          leading: _leading(
            theme,
            color: isDestructive ? theme.colorScheme.error : null,
          ),
          // Only navigational rows get a chevron. Showing one on every row
          // promises navigation that a destructive or inert action does not
          // deliver.
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
          enabled: onTap != null,
        ),
    };
  }

  Widget? _leading(ThemeData theme, {Color? color}) {
    final icon = item.icon;
    if (icon == null) return null;
    return Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant);
  }
}
