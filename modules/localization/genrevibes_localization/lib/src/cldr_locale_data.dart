import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';

/// Registers host-bundled CLDR Gregorian/numeric data missing from intl.
/// The host supplies the CLDR release, territory and currency; no network calls
/// or fixed portfolio language list belong in this package.
void registerCldrLocale({
  required String locale,
  required Map<String, dynamic> data,
  required Map<String, dynamic> weekData,
  required String territory,
  required String currencyCode,
}) {
  final calendar = data['gregorian'] as Map<String, dynamic>;
  final numbers = data['numbers'] as Map<String, dynamic>;
  final numberingSystem = numbers['defaultNumberingSystem'] as String;
  final zero = switch (numberingSystem) {
    'arab' => '٠',
    'arabext' => '۰',
    'latn' => '0',
    _ => throw ArgumentError('Unsupported numbering system: $numberingSystem'),
  };
  final numeric = numbers['symbols-numberSystem-$numberingSystem'] as Map;
  String pattern(String kind) =>
      (numbers['${kind}Formats-numberSystem-$numberingSystem']
          as Map)['standard'] as String;
  numberFormatSymbols[locale] = NumberSymbols(
    NAME: locale,
    DECIMAL_SEP: numeric['decimal'] as String,
    GROUP_SEP: numeric['group'] as String,
    PERCENT: numeric['percentSign'] as String,
    ZERO_DIGIT: zero,
    PLUS_SIGN: numeric['plusSign'] as String,
    MINUS_SIGN: numeric['minusSign'] as String,
    EXP_SYMBOL: numeric['exponential'] as String,
    PERMILL: numeric['perMille'] as String,
    INFINITY: numeric['infinity'] as String,
    NAN: numeric['nan'] as String,
    DECIMAL_PATTERN: pattern('decimal'),
    SCIENTIFIC_PATTERN: pattern('scientific'),
    PERCENT_PATTERN: pattern('percent'),
    CURRENCY_PATTERN: pattern('currency'),
    DEF_CURRENCY_CODE: currencyCode,
  );

  List<String> names(String unit, String context, String width) {
    final values = (calendar[unit] as Map)[context][width] as Map;
    final keys = unit == 'days'
        ? ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
        : List.generate(unit == 'months' ? 12 : 4, (i) => '${i + 1}');
    return [for (final key in keys) values[key] as String];
  }

  List<String> formats(String key) => [
        for (final width in ['full', 'long', 'medium', 'short'])
          (calendar[key] as Map)[width] as String,
      ];
  int weekDay(String key) {
    final values = weekData[key] as Map;
    return ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].indexOf(
      (values[territory] ?? values['001']) as String,
    );
  }

  final eras = calendar['eras'] as Map;
  final periods =
      (calendar['dayPeriods'] as Map)['format']['abbreviated'] as Map;
  final available = Map<String, String>.from(
    (calendar['dateTimeFormats'] as Map)['availableFormats'] as Map,
  );
  final dateFormats = formats('dateFormats');
  final timeFormats = formats('timeFormats');
  final patterns = <String, String>{
    ...available,
    'EEEE': 'EEEE',
    'MMMEd': available['MMMEd']!,
    'yMMMMEEEEd': dateFormats[0],
    'yMMMMd': dateFormats[1],
    'j': available[timeFormats[3].contains('H') ? 'H' : 'h']!,
    'jm': timeFormats[3],
    'jms': timeFormats[2],
  };
  initializeDateFormattingCustom(
    locale: locale,
    symbols: DateSymbols(
      NAME: locale,
      ERAS: [eras['eraAbbr']['0'] as String, eras['eraAbbr']['1'] as String],
      ERANAMES: [
        eras['eraNames']['0'] as String,
        eras['eraNames']['1'] as String
      ],
      NARROWMONTHS: names('months', 'format', 'narrow'),
      STANDALONENARROWMONTHS: names('months', 'stand-alone', 'narrow'),
      MONTHS: names('months', 'format', 'wide'),
      STANDALONEMONTHS: names('months', 'stand-alone', 'wide'),
      SHORTMONTHS: names('months', 'format', 'abbreviated'),
      STANDALONESHORTMONTHS: names('months', 'stand-alone', 'abbreviated'),
      WEEKDAYS: names('days', 'format', 'wide'),
      STANDALONEWEEKDAYS: names('days', 'stand-alone', 'wide'),
      SHORTWEEKDAYS: names('days', 'format', 'abbreviated'),
      STANDALONESHORTWEEKDAYS: names('days', 'stand-alone', 'abbreviated'),
      NARROWWEEKDAYS: names('days', 'format', 'narrow'),
      STANDALONENARROWWEEKDAYS: names('days', 'stand-alone', 'narrow'),
      SHORTQUARTERS: names('quarters', 'format', 'abbreviated'),
      QUARTERS: names('quarters', 'format', 'wide'),
      AMPMS: [periods['am'] as String, periods['pm'] as String],
      ZERODIGIT: zero,
      DATEFORMATS: dateFormats,
      TIMEFORMATS: timeFormats,
      AVAILABLEFORMATS: patterns,
      FIRSTDAYOFWEEK: weekDay('firstDay'),
      WEEKENDRANGE: [weekDay('weekendStart'), weekDay('weekendEnd')],
      FIRSTWEEKCUTOFFDAY: (7 -
              int.parse(
                ((weekData['minDays'] as Map)[territory] ??
                        (weekData['minDays'] as Map)['001'])
                    .toString(),
              )) %
          7,
      DATETIMEFORMATS: formats('dateTimeFormats'),
    ),
    patterns: patterns,
  );
}
