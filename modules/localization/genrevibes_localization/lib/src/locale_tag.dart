import 'package:flutter/widgets.dart';

/// The language, optional writing system, and optional region of a BCP 47 tag.
/// Extensions and private-use tags are deliberately outside this API's scope.
final class LocaleTag {
  const LocaleTag._(this.language, this.script, this.region);

  final String language;
  final String? script;
  final String? region;

  static LocaleTag? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().replaceAll('_', '-').split('-');
    if (!RegExp(r'^[a-zA-Z]{2,3}$').hasMatch(parts.first)) return null;
    final language = switch (parts.first.toLowerCase()) {
      'iw' => 'he',
      'in' => 'id',
      'ji' => 'yi',
      final code => code,
    };
    String? script;
    String? region;
    var i = 1;
    if (i < parts.length && RegExp(r'^[a-zA-Z]{4}$').hasMatch(parts[i])) {
      final raw = parts[i++].toLowerCase();
      script = '${raw[0].toUpperCase()}${raw.substring(1)}';
    }
    if (i < parts.length &&
        RegExp(r'^(?:[a-zA-Z]{2}|[0-9]{3})$').hasMatch(parts[i])) {
      region = parts[i++].toUpperCase();
      if (region == 'UK') region = 'GB';
    }
    return i == parts.length ? LocaleTag._(language, script, region) : null;
  }

  factory LocaleTag.parse(String value) =>
      tryParse(value) ?? (throw FormatException('Invalid locale tag', value));

  factory LocaleTag.fromLocale(Locale locale) => LocaleTag._(
        locale.languageCode,
        locale.scriptCode,
        locale.countryCode,
      );

  String get tag => [
        language,
        if (script != null) script!,
        if (region != null) region!
      ].join('-');

  /// Infer only script distinctions which would otherwise cause wrong-script
  /// matching. Other scripts remain explicitly supplied by the app catalogue.
  String? get effectiveScript =>
      script ??
      switch (language) {
        'zh' => const {'TW', 'HK', 'MO'}.contains(region) ? 'Hant' : 'Hans',
        'pa' => region == 'PK' ? 'Arab' : 'Guru',
        'uz' => 'Latn',
        _ => null,
      };

  bool compatibleWith(LocaleTag other) =>
      language == other.language && effectiveScript == other.effectiveScript;

  Locale get locale => Locale.fromSubtags(
      languageCode: language, scriptCode: script, countryCode: region);

  LocaleTag withRegion(String? region) => LocaleTag._(language, script, region);

  @override
  String toString() => tag;

  @override
  bool operator ==(Object other) => other is LocaleTag && tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}
