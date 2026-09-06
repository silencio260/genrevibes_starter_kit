import 'package:flutter/widgets.dart';

/// One row in a settings list.
///
/// A sealed hierarchy rather than a single configurable class, so a row cannot
/// be constructed in a contradictory state such as a toggle that also navigates.
sealed class SettingsItem {
  const SettingsItem({required this.title, this.subtitle, this.icon});

  /// Primary label.
  final String title;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the row responds to interaction.
  bool get isEnabled;
}

/// A row that performs an action when tapped.
final class SettingsAction extends SettingsItem {
  /// Creates an action row.
  const SettingsAction({
    required super.title,
    required this.onTap,
    super.subtitle,
    super.icon,
    this.isDestructive = false,
  });

  /// Invoked when the row is tapped. `null` disables the row.
  final VoidCallback? onTap;

  /// Whether this action is destructive and should be styled as a warning.
  final bool isDestructive;

  @override
  bool get isEnabled => onTap != null;
}

/// A row carrying an on/off switch.
final class SettingsToggle extends SettingsItem {
  /// Creates a toggle row.
  const SettingsToggle({
    required super.title,
    required this.value,
    required this.onChanged,
    super.subtitle,
    super.icon,
  });

  /// Current state.
  final bool value;

  /// Invoked when the user changes the switch. `null` disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  bool get isEnabled => onChanged != null;
}

/// A row showing a read-only value, such as an app version.
final class SettingsInfo extends SettingsItem {
  /// Creates an informational row.
  const SettingsInfo({
    required super.title,
    required this.value,
    super.subtitle,
    super.icon,
  });

  /// Value shown at the end of the row.
  final String value;

  @override
  bool get isEnabled => false;
}

/// A row rendering caller-supplied content.
final class SettingsCustom extends SettingsItem {
  /// Creates a custom row.
  const SettingsCustom({required super.title, required this.builder});

  /// Builds the row body.
  final WidgetBuilder builder;

  @override
  bool get isEnabled => true;
}
