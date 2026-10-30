import 'package:flutter/material.dart';

import 'localization_configuration.dart';

/// Distinguishes choosing device defaults (value == null) from dismissing.
final class LocalizationChoice {
  const LocalizationChoice(this.value);
  final String? value;
}

/// Every visible label is supplied by the host app's current translations.
final class LocalizationPickerLabels {
  const LocalizationPickerLabels(
      {required this.title,
      required this.search,
      required this.deviceDefault,
      required this.noResults,
      required this.close});
  final String title;
  final String search;
  final String deviceDefault;
  final String noResults;
  final String close;
}

final class LocalizationPickerItem {
  const LocalizationPickerItem(
      {required this.value,
      required this.title,
      this.subtitle,
      this.leading,
      this.titleDirection,
      this.subtitleDirection,
      this.searchTerms = ''});
  final String value;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final TextDirection? titleDirection;
  final TextDirection? subtitleDirection;
  final String searchTerms;

  factory LocalizationPickerItem.locale(LocaleOption locale) =>
      LocalizationPickerItem(
        value: locale.tag,
        title: locale.nativeName,
        subtitle:
            locale.displayName == locale.nativeName ? null : locale.displayName,
        searchTerms: '${locale.tag} ${locale.displayName}',
      );

  factory LocalizationPickerItem.country(CountryOption country) =>
      LocalizationPickerItem(
        value: country.code,
        title: country.name,
        searchTerms: '${country.code} ${country.searchTerms}',
      );
}

/// Searchable picker usable in a host-owned sheet, page, or dialog.
class LocalizationPicker extends StatefulWidget {
  const LocalizationPicker(
      {super.key,
      required this.items,
      required this.labels,
      required this.selected,
      required this.onSelected});
  final List<LocalizationPickerItem> items;
  final LocalizationPickerLabels labels;
  final String? selected;
  final ValueChanged<LocalizationChoice> onSelected;

  @override
  State<LocalizationPicker> createState() => _LocalizationPickerState();
}

class _LocalizationPickerState extends State<LocalizationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.items
        .where((item) =>
            '${item.title} ${item.subtitle ?? ''} ${item.searchTerms}'
                .toLowerCase()
                .contains(query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(children: [
            Expanded(
                child: Text(widget.labels.title,
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: widget.labels.close,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
                labelText: widget.labels.search,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: matches.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(widget.labels.deviceDefault),
                  selected: widget.selected == null,
                  leading: const Icon(Icons.phone_android_outlined),
                  trailing:
                      widget.selected == null ? const Icon(Icons.check) : null,
                  onTap: () =>
                      widget.onSelected(const LocalizationChoice(null)),
                );
              }
              final item = matches[index - 1];
              return ListTile(
                leading: item.leading,
                title: Text(item.title, textDirection: item.titleDirection),
                subtitle: item.subtitle == null
                    ? null
                    : Text(item.subtitle!,
                        textDirection: item.subtitleDirection),
                selected: widget.selected == item.value,
                trailing: widget.selected == item.value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => widget.onSelected(LocalizationChoice(item.value)),
              );
            },
          ),
        ),
        if (matches.isEmpty)
          Padding(
              padding: const EdgeInsets.all(20),
              child:
                  Text(widget.labels.noResults, textAlign: TextAlign.center)),
      ],
    );
  }
}

Future<LocalizationChoice?> showLocalizationPicker({
  required BuildContext context,
  required List<LocalizationPickerItem> items,
  required LocalizationPickerLabels labels,
  required String? selected,
}) =>
    showDialog<LocalizationChoice>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 440,
          height: MediaQuery.of(context).size.height * .75,
          child: LocalizationPicker(
              items: items,
              labels: labels,
              selected: selected,
              onSelected: (choice) => Navigator.of(context).pop(choice)),
        ),
      ),
    );
