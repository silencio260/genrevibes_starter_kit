import 'package:flutter/widgets.dart';

import 'locale_tag.dart';

/// One app-supplied locale. Unready options stay in the catalogue but are never
/// returned by resolution or displayed by the selection widget.
final class LocaleOption {
  const LocaleOption({
    required this.tag,
    required this.nativeName,
    required this.displayName,
    this.translationTag,
    this.direction = TextDirection.ltr,
    this.enabled = true,
  });

  final String tag;
  final String nativeName;
  final String displayName;
  final String? translationTag;
  final TextDirection direction;
  final bool enabled;

  LocaleTag get parsed => LocaleTag.parse(tag);
  Locale get locale => parsed.locale;
  Locale get translationLocale => LocaleTag.parse(translationTag ?? tag).locale;
}

final class CountryOption {
  const CountryOption(
      {required this.code, required this.name, this.searchTerms = ''});

  final String code;
  final String name;
  final String searchTerms;
}

/// Immutable host configuration. Product strings and available languages are
/// intentionally supplied by the host, rather than stored in this package.
final class LocalizationConfiguration {
  LocalizationConfiguration({
    required List<LocaleOption> locales,
    required List<CountryOption> countries,
    required this.defaultTag,
    required this.storageKey,
    Map<String, String> aliases = const {},
    Set<String> formattingLocales = const {},
  })  : locales = List.unmodifiable(locales),
        countries = List.unmodifiable(countries),
        aliases = Map.unmodifiable(aliases),
        formattingLocales = Set.unmodifiable(formattingLocales) {
    final tags = <String>{};
    for (final option in locales) {
      if (option.parsed.tag != option.tag || !tags.add(option.tag)) {
        throw ArgumentError(
            'Locale tags must be unique and canonical: ${option.tag}');
      }
      final source = LocaleTag.parse(option.translationTag ?? option.tag);
      if (!source.compatibleWith(option.parsed)) {
        throw ArgumentError(
            'Translation parent has a different language or script: ${option.tag}');
      }
    }
    if (!enabledLocales.any((option) => option.tag == defaultTag)) {
      throw ArgumentError('The default locale must be enabled.');
    }
    if (storageKey.isEmpty) {
      throw ArgumentError('An app-specific storage key is required.');
    }
    final codes = <String>{};
    for (final country in countries) {
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(country.code) ||
          !codes.add(country.code)) {
        throw ArgumentError('Country codes must be unique ISO alpha-2 codes.');
      }
    }
    for (final entry in aliases.entries) {
      if (LocaleTag.tryParse(entry.key) == null ||
          !tags.contains(entry.value)) {
        throw ArgumentError('Invalid locale alias: ${entry.key}');
      }
    }
  }

  final List<LocaleOption> locales;
  final List<CountryOption> countries;
  final String defaultTag;
  final String storageKey;
  final Map<String, String> aliases;
  final Set<String> formattingLocales;

  Iterable<LocaleOption> get enabledLocales =>
      locales.where((option) => option.enabled);
  LocaleOption get defaultLocale =>
      enabledLocales.firstWhere((option) => option.tag == defaultTag);

  String? normalize(String? tag) {
    final parsed = LocaleTag.tryParse(tag);
    return parsed == null ? null : aliases[parsed.tag] ?? parsed.tag;
  }

  LocaleOption? exact(String? tag) {
    final normalized = normalize(tag);
    for (final option in enabledLocales) {
      if (option.tag == normalized) return option;
    }
    return null;
  }

  /// Search all device preferences before using the configured app default.
  LocaleOption resolve(Iterable<String> preferredTags) {
    for (final raw in preferredTags) {
      final preferred = LocaleTag.tryParse(normalize(raw));
      if (preferred == null) continue;
      final exactMatch = exact(preferred.tag);
      if (exactMatch != null) return exactMatch;
      final candidates = enabledLocales
          .where((option) => option.parsed.compatibleWith(preferred))
          .toList();
      if (candidates.isEmpty) continue;
      for (final option in candidates) {
        if (option.parsed.region == preferred.region) return option;
      }
      for (final option in candidates) {
        if (option.tag == defaultTag) return option;
      }
      return candidates.first;
    }
    return defaultLocale;
  }

  /// Never pass an unknown region tag to a formatter. The host supplies the
  /// data actually registered by its formatting library, in canonical spelling.
  Locale formattingLocale(LocaleOption option, String? country) {
    final tag = option.parsed;
    final regional = country == null ? tag : tag.withRegion(country);
    final candidates = <LocaleTag>[
      regional,
      tag,
      LocaleTag.parse(option.translationTag ?? option.tag),
      LocaleTag.parse(tag.language),
      LocaleTag.parse(defaultLocale.translationTag ?? defaultTag),
    ];
    if (formattingLocales.isEmpty) return option.translationLocale;
    for (final candidate in candidates) {
      if (formattingLocales.contains(candidate.tag)) return candidate.locale;
    }
    throw StateError('No registered formatting data for the app default.');
  }
}
