import 'settings_item.dart';

/// A titled group of settings rows.
final class SettingsSection {
  /// Creates a section.
  SettingsSection({
    required List<SettingsItem> items,
    this.title,
    this.footer,
  }) : items = List<SettingsItem>.unmodifiable(items);

  /// Optional group heading.
  final String? title;

  /// Optional explanatory text below the group.
  final String? footer;

  /// Rows in display order.
  final List<SettingsItem> items;

  /// Whether this section would render anything.
  bool get isEmpty => items.isEmpty;
}
