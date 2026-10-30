import 'package:flutter/material.dart';

import 'localization_picker.dart';

/// A full-screen picker with a draft selection. Back cancels; confirm returns
/// the choice, including null when the user chooses the device default.
class LocalizationPickerPage extends StatefulWidget {
  const LocalizationPickerPage({
    super.key,
    required this.items,
    required this.labels,
    required this.selected,
    required this.confirmLabel,
    this.description,
    this.layoutDirection,
    this.onConfirmed,
    this.isSaving = false,
  });

  final List<LocalizationPickerItem> items;
  final LocalizationPickerLabels labels;
  final String? selected;
  final String confirmLabel;
  final String? description;

  /// For an embedded startup step. When absent, confirmation pops this route.
  final ValueChanged<LocalizationChoice>? onConfirmed;
  final bool isSaving;

  /// Controls physical placement independently of each label's reading order.
  /// Null follows the surrounding layout direction.
  final TextDirection? layoutDirection;

  @override
  State<LocalizationPickerPage> createState() => _LocalizationPickerPageState();
}

class _LocalizationPickerPageState extends State<LocalizationPickerPage> {
  late String? _selected = widget.selected;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textDirection = Directionality.of(context);
    final layoutDirection = widget.layoutDirection ?? textDirection;
    final labelAlignment =
        layoutDirection == TextDirection.ltr ? TextAlign.left : TextAlign.right;
    final query = _query.trim().toLowerCase();
    final matches = widget.items.where((item) {
      return '${item.title} ${item.subtitle ?? ''} ${item.searchTerms}'
          .toLowerCase()
          .contains(query);
    }).toList();
    final showDevice = query.isEmpty ||
        widget.labels.deviceDefault.toLowerCase().contains(query);
    final count = matches.length + (showDevice ? 1 : 0);

    return Directionality(
      textDirection: layoutDirection,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.onConfirmed == null,
          centerTitle: true,
          title: Text(widget.labels.title,
              textDirection: textDirection,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              tooltip: widget.confirmLabel,
              onPressed: widget.isSaving
                  ? null
                  : () {
                      final choice = LocalizationChoice(_selected);
                      final onConfirmed = widget.onConfirmed;
                      if (onConfirmed != null) {
                        onConfirmed(choice);
                      } else {
                        Navigator.of(context).pop(choice);
                      }
                    },
              icon: widget.isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.check_rounded, color: colors.primary, size: 28),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.description != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      child: Text(widget.description!,
                          textDirection: textDirection,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TextField(
                      enabled: !widget.isSaving,
                      textDirection: textDirection,
                      textAlign: labelAlignment,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: widget.labels.search,
                        hintTextDirection: textDirection,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: count == 0
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(widget.labels.noResults,
                                  textDirection: textDirection,
                                  textAlign: TextAlign.center),
                            ),
                          )
                        : Scrollbar(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: count,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final device = showDevice && index == 0;
                                final item = device
                                    ? null
                                    : matches[index - (showDevice ? 1 : 0)];
                                final value = item?.value;
                                final selected = _selected == value;
                                return Semantics(
                                  selected: selected,
                                  inMutuallyExclusiveGroup: true,
                                  child: Material(
                                    color: selected
                                        ? Color.alphaBlend(
                                            colors.primary.withAlpha(24),
                                            colors.surface,
                                          )
                                        : colors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: selected
                                            ? colors.primary
                                            : colors.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: widget.isSaving
                                          ? null
                                          : () =>
                                              setState(() => _selected = value),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            item?.leading ??
                                                Icon(
                                                  device
                                                      ? Icons
                                                          .phone_android_rounded
                                                      : Icons.language_rounded,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  size: 30,
                                                ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                    item?.title ??
                                                        widget.labels
                                                            .deviceDefault,
                                                    textDirection:
                                                        item?.titleDirection ??
                                                            textDirection,
                                                    textAlign: labelAlignment,
                                                    style: theme
                                                        .textTheme.bodyLarge
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (item?.subtitle !=
                                                      null) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item!.subtitle!,
                                                      textDirection:
                                                          item.subtitleDirection ??
                                                              textDirection,
                                                      textAlign: labelAlignment,
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: colors
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              selected
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              size: 22,
                                              color: selected
                                                  ? colors.primary
                                                  : colors.outline,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<LocalizationChoice?> showLocalizationPickerPage({
  required BuildContext context,
  required List<LocalizationPickerItem> items,
  required LocalizationPickerLabels labels,
  required String? selected,
  required String confirmLabel,
  String? description,
  TextDirection? layoutDirection,
}) =>
    Navigator.of(context, rootNavigator: true).push<LocalizationChoice>(
      MaterialPageRoute(
        builder: (_) => LocalizationPickerPage(
          items: items,
          labels: labels,
          selected: selected,
          confirmLabel: confirmLabel,
          description: description,
          layoutDirection: layoutDirection,
        ),
      ),
    );
