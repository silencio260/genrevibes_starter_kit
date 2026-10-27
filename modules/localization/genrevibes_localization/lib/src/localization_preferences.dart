/// A null selection follows the device. Persisting that null is an explicit
/// choice, distinct from a device which has never saved a preference.
final class LocalizationPreferences {
  const LocalizationPreferences({this.localeTag, this.countryCode});

  final String? localeTag;
  final String? countryCode;

  Map<String, Object?> toJson() => {
        'version': 1,
        'localeTag': localeTag,
        'countryCode': countryCode,
      };

  static LocalizationPreferences? fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) return null;
    final locale = value['localeTag'];
    final country = value['countryCode'];
    if (locale != null && locale is! String ||
        country != null && country is! String) {
      return null;
    }
    return LocalizationPreferences(
        localeTag: locale as String?, countryCode: country as String?);
  }
}
