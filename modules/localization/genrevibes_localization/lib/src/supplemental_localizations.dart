// Typed API bindings derived from Flutter's generated localization interface.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Flutter's BSD license is retained in licenses/flutter.txt.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'locale_tag.dart';

/// App-owned labels and formatting for a language absent from Flutter's bundles,
/// or a writing system needing a different bundle (for example Arabic Punjabi).
final class SupplementalLocaleData {
  SupplementalLocaleData({
    required this.localeName,
    required Map<String, String> labels,
    required this.direction,
    this.scriptCategory = ScriptCategory.englishLike,
    this.uses24HourClock = false,
  }) : labels = Map.unmodifiable(labels) {
    final missing = _requiredLabels.difference(labels.keys.toSet());
    if (missing.isNotEmpty) {
      throw ArgumentError('Missing framework labels for $localeName: $missing');
    }
    if (_requiredLabels.any((key) => labels[key]!.trim().isEmpty)) {
      throw ArgumentError('Empty framework label for $localeName');
    }
  }

  final String localeName;
  final Map<String, String> labels;
  final TextDirection direction;
  final ScriptCategory scriptCategory;
  final bool uses24HourClock;

  String label(String key) => labels[key]!;
  DateFormat get compactDate => DateFormat.yMd(localeName);
  String get dateOrder => (RegExp(r'[yMd]+')
          .allMatches(compactDate.pattern!)
          .map((part) => part[0]![0])
          .toList())
      .join();
  String get dateHelp => compactDate.pattern!
      .replaceAll(RegExp(r'y+'), 'yyyy')
      .replaceAll('M', 'm');
}

/// Put these delegates before GlobalMaterial/Widgets/CupertinoLocalizations.
/// Loaders run once per resource and must register intl data before returning.
/// Keys are language or language-script tags; exact script wins over language.
final class SupplementalLocalizations {
  SupplementalLocalizations(
      Map<String, Future<SupplementalLocaleData> Function()> loaders)
      : _loaders = Map.unmodifiable(loaders);

  final Map<String, Future<SupplementalLocaleData> Function()> _loaders;
  final Map<String, Future<SupplementalLocaleData>> _cache = {};

  String? _key(Locale locale) {
    final tag = LocaleTag.fromLocale(locale);
    for (final key in [
      tag.tag,
      '${tag.language}-${tag.effectiveScript}',
      tag.language
    ]) {
      if (_loaders.containsKey(key)) return key;
    }
    return null;
  }

  bool supports(Locale locale) => _key(locale) != null;
  Future<SupplementalLocaleData> _load(Locale locale) {
    final key = _key(locale)!;
    return _cache.putIfAbsent(key, () async {
      try {
        return await _loaders[key]!();
      } catch (_) {
        _cache.remove(key);
        rethrow;
      }
    });
  }

  late final List<LocalizationsDelegate<dynamic>> delegates =
      List.unmodifiable([
    _SupplementalMaterialDelegate(this),
    _SupplementalWidgetsDelegate(this),
    _SupplementalCupertinoDelegate(this),
  ]);
}

class _SupplementalMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _SupplementalMaterialDelegate(this.owner);
  final SupplementalLocalizations owner;
  @override
  bool isSupported(Locale locale) => owner.supports(locale);
  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      _SupplementalMaterial(await owner._load(locale));
  @override
  bool shouldReload(_SupplementalMaterialDelegate old) => old.owner != owner;
}

class _SupplementalCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _SupplementalCupertinoDelegate(this.owner);
  final SupplementalLocalizations owner;
  @override
  bool isSupported(Locale locale) => owner.supports(locale);
  @override
  Future<CupertinoLocalizations> load(Locale locale) async =>
      _SupplementalCupertino(await owner._load(locale));
  @override
  bool shouldReload(_SupplementalCupertinoDelegate old) => old.owner != owner;
}

class _SupplementalWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _SupplementalWidgetsDelegate(this.owner);
  final SupplementalLocalizations owner;
  @override
  bool isSupported(Locale locale) => owner.supports(locale);
  @override
  Future<WidgetsLocalizations> load(Locale locale) async =>
      _SupplementalWidgets((await owner._load(locale)).direction);
  @override
  bool shouldReload(_SupplementalWidgetsDelegate old) => old.owner != owner;
}

class _SupplementalWidgets extends DefaultWidgetsLocalizations {
  const _SupplementalWidgets(this.textDirection);
  @override
  final TextDirection textDirection;
}

// Typed bindings for Flutter's framework label API, checked with Flutter 3.44.
// English supplies only formatting machinery and absent optional plural forms;
// every non-null label is required from the app-supplied dictionary above.
class _SupplementalMaterial extends MaterialLocalizationEn {
  _SupplementalMaterial(this.data)
      : super(
          localeName: data.localeName,
          fullYearFormat: DateFormat.y(data.localeName),
          compactDateFormat: data.compactDate,
          shortDateFormat: DateFormat.yMMMd(data.localeName),
          mediumDateFormat: DateFormat.MMMEd(data.localeName),
          longDateFormat: DateFormat.yMMMMEEEEd(data.localeName),
          yearMonthFormat: DateFormat.yMMMM(data.localeName),
          shortMonthDayFormat: DateFormat.MMMd(data.localeName),
          decimalFormat: NumberFormat.decimalPattern(data.localeName),
          twoDigitZeroPaddedFormat: NumberFormat('00', data.localeName),
        );
  final SupplementalLocaleData data;
  @override
  ScriptCategory get scriptCategory => data.scriptCategory;
  @override
  TimeOfDayFormat get timeOfDayFormatRaw => data.uses24HourClock
      ? TimeOfDayFormat.HH_colon_mm
      : TimeOfDayFormat.h_colon_mm_space_a;
  @override
  String get dateHelpText => data.dateHelp;
  @override
  String get aboutListTileTitleRaw => data.label('aboutListTileTitleRaw');
  @override
  String get alertDialogLabel => data.label('alertDialogLabel');
  @override
  String get anteMeridiemAbbreviation => data.label('anteMeridiemAbbreviation');
  @override
  String get backButtonTooltip => data.label('backButtonTooltip');
  @override
  String get bottomSheetLabel => data.label('bottomSheetLabel');
  @override
  String get calendarModeButtonLabel => data.label('calendarModeButtonLabel');
  @override
  String get cancelButtonLabel => data.label('cancelButtonLabel');
  @override
  String get clearButtonTooltip => data.label('clearButtonTooltip');
  @override
  String get closeButtonLabel => data.label('closeButtonLabel');
  @override
  String get closeButtonTooltip => data.label('closeButtonTooltip');
  @override
  String get collapsedHint => data.label('collapsedHint');
  @override
  String get collapsedIconTapHint => data.label('collapsedIconTapHint');
  @override
  String get continueButtonLabel => data.label('continueButtonLabel');
  @override
  String get copyButtonLabel => data.label('copyButtonLabel');
  @override
  String get currentDateLabel => data.label('currentDateLabel');
  @override
  String get cutButtonLabel => data.label('cutButtonLabel');
  @override
  String get dateInputLabel => data.label('dateInputLabel');
  @override
  String get dateOutOfRangeLabel => data.label('dateOutOfRangeLabel');
  @override
  String get datePickerHelpText => data.label('datePickerHelpText');
  @override
  String get dateRangeEndDateSemanticLabelRaw =>
      data.label('dateRangeEndDateSemanticLabelRaw');
  @override
  String get dateRangeEndLabel => data.label('dateRangeEndLabel');
  @override
  String get dateRangePickerHelpText => data.label('dateRangePickerHelpText');
  @override
  String get dateRangeStartDateSemanticLabelRaw =>
      data.label('dateRangeStartDateSemanticLabelRaw');
  @override
  String get dateRangeStartLabel => data.label('dateRangeStartLabel');
  @override
  String get dateSeparator => data.label('dateSeparator');
  @override
  String get deleteButtonTooltip => data.label('deleteButtonTooltip');
  @override
  String get dialModeButtonLabel => data.label('dialModeButtonLabel');
  @override
  String get dialogLabel => data.label('dialogLabel');
  @override
  String get drawerLabel => data.label('drawerLabel');
  @override
  String get expandedHint => data.label('expandedHint');
  @override
  String get expandedIconTapHint => data.label('expandedIconTapHint');
  @override
  String get expansionTileCollapsedHint =>
      data.label('expansionTileCollapsedHint');
  @override
  String get expansionTileCollapsedTapHint =>
      data.label('expansionTileCollapsedTapHint');
  @override
  String get expansionTileExpandedHint =>
      data.label('expansionTileExpandedHint');
  @override
  String get expansionTileExpandedTapHint =>
      data.label('expansionTileExpandedTapHint');
  @override
  String get firstPageTooltip => data.label('firstPageTooltip');
  @override
  String get hideAccountsLabel => data.label('hideAccountsLabel');
  @override
  String get inputDateModeButtonLabel => data.label('inputDateModeButtonLabel');
  @override
  String get inputTimeModeButtonLabel => data.label('inputTimeModeButtonLabel');
  @override
  String get invalidDateFormatLabel => data.label('invalidDateFormatLabel');
  @override
  String get invalidDateRangeLabel => data.label('invalidDateRangeLabel');
  @override
  String get invalidTimeLabel => data.label('invalidTimeLabel');
  @override
  String get keyboardKeyAlt => data.label('keyboardKeyAlt');
  @override
  String get keyboardKeyAltGraph => data.label('keyboardKeyAltGraph');
  @override
  String get keyboardKeyBackspace => data.label('keyboardKeyBackspace');
  @override
  String get keyboardKeyCapsLock => data.label('keyboardKeyCapsLock');
  @override
  String get keyboardKeyChannelDown => data.label('keyboardKeyChannelDown');
  @override
  String get keyboardKeyChannelUp => data.label('keyboardKeyChannelUp');
  @override
  String get keyboardKeyControl => data.label('keyboardKeyControl');
  @override
  String get keyboardKeyDelete => data.label('keyboardKeyDelete');
  @override
  String get keyboardKeyEject => data.label('keyboardKeyEject');
  @override
  String get keyboardKeyEnd => data.label('keyboardKeyEnd');
  @override
  String get keyboardKeyEscape => data.label('keyboardKeyEscape');
  @override
  String get keyboardKeyFn => data.label('keyboardKeyFn');
  @override
  String get keyboardKeyHome => data.label('keyboardKeyHome');
  @override
  String get keyboardKeyInsert => data.label('keyboardKeyInsert');
  @override
  String get keyboardKeyMeta => data.label('keyboardKeyMeta');
  @override
  String get keyboardKeyMetaMacOs => data.label('keyboardKeyMetaMacOs');
  @override
  String get keyboardKeyMetaWindows => data.label('keyboardKeyMetaWindows');
  @override
  String get keyboardKeyNumLock => data.label('keyboardKeyNumLock');
  @override
  String get keyboardKeyNumpad0 => data.label('keyboardKeyNumpad0');
  @override
  String get keyboardKeyNumpad1 => data.label('keyboardKeyNumpad1');
  @override
  String get keyboardKeyNumpad2 => data.label('keyboardKeyNumpad2');
  @override
  String get keyboardKeyNumpad3 => data.label('keyboardKeyNumpad3');
  @override
  String get keyboardKeyNumpad4 => data.label('keyboardKeyNumpad4');
  @override
  String get keyboardKeyNumpad5 => data.label('keyboardKeyNumpad5');
  @override
  String get keyboardKeyNumpad6 => data.label('keyboardKeyNumpad6');
  @override
  String get keyboardKeyNumpad7 => data.label('keyboardKeyNumpad7');
  @override
  String get keyboardKeyNumpad8 => data.label('keyboardKeyNumpad8');
  @override
  String get keyboardKeyNumpad9 => data.label('keyboardKeyNumpad9');
  @override
  String get keyboardKeyNumpadAdd => data.label('keyboardKeyNumpadAdd');
  @override
  String get keyboardKeyNumpadComma => data.label('keyboardKeyNumpadComma');
  @override
  String get keyboardKeyNumpadDecimal => data.label('keyboardKeyNumpadDecimal');
  @override
  String get keyboardKeyNumpadDivide => data.label('keyboardKeyNumpadDivide');
  @override
  String get keyboardKeyNumpadEnter => data.label('keyboardKeyNumpadEnter');
  @override
  String get keyboardKeyNumpadEqual => data.label('keyboardKeyNumpadEqual');
  @override
  String get keyboardKeyNumpadMultiply =>
      data.label('keyboardKeyNumpadMultiply');
  @override
  String get keyboardKeyNumpadParenLeft =>
      data.label('keyboardKeyNumpadParenLeft');
  @override
  String get keyboardKeyNumpadParenRight =>
      data.label('keyboardKeyNumpadParenRight');
  @override
  String get keyboardKeyNumpadSubtract =>
      data.label('keyboardKeyNumpadSubtract');
  @override
  String get keyboardKeyPageDown => data.label('keyboardKeyPageDown');
  @override
  String get keyboardKeyPageUp => data.label('keyboardKeyPageUp');
  @override
  String get keyboardKeyPower => data.label('keyboardKeyPower');
  @override
  String get keyboardKeyPowerOff => data.label('keyboardKeyPowerOff');
  @override
  String get keyboardKeyPrintScreen => data.label('keyboardKeyPrintScreen');
  @override
  String get keyboardKeyScrollLock => data.label('keyboardKeyScrollLock');
  @override
  String get keyboardKeySelect => data.label('keyboardKeySelect');
  @override
  String get keyboardKeyShift => data.label('keyboardKeyShift');
  @override
  String get keyboardKeySpace => data.label('keyboardKeySpace');
  @override
  String get lastPageTooltip => data.label('lastPageTooltip');
  @override
  String? get licensesPackageDetailTextOne =>
      data.label('licensesPackageDetailTextOne');
  @override
  String get licensesPackageDetailTextOther =>
      data.label('licensesPackageDetailTextOther');
  @override
  String? get licensesPackageDetailTextZero =>
      data.label('licensesPackageDetailTextZero');
  @override
  String get licensesPageTitle => data.label('licensesPageTitle');
  @override
  String get lookUpButtonLabel => data.label('lookUpButtonLabel');
  @override
  String get menuBarMenuLabel => data.label('menuBarMenuLabel');
  @override
  String get menuDismissLabel => data.label('menuDismissLabel');
  @override
  String get modalBarrierDismissLabel => data.label('modalBarrierDismissLabel');
  @override
  String get moreButtonTooltip => data.label('moreButtonTooltip');
  @override
  String get nextMonthTooltip => data.label('nextMonthTooltip');
  @override
  String get nextPageTooltip => data.label('nextPageTooltip');
  @override
  String get okButtonLabel => data.label('okButtonLabel');
  @override
  String get openAppDrawerTooltip => data.label('openAppDrawerTooltip');
  @override
  String get pageRowsInfoTitleRaw => data.label('pageRowsInfoTitleRaw');
  @override
  String get pageRowsInfoTitleApproximateRaw =>
      data.label('pageRowsInfoTitleApproximateRaw');
  @override
  String get pasteButtonLabel => data.label('pasteButtonLabel');
  @override
  String get popupMenuLabel => data.label('popupMenuLabel');
  @override
  String get postMeridiemAbbreviation => data.label('postMeridiemAbbreviation');
  @override
  String get previousMonthTooltip => data.label('previousMonthTooltip');
  @override
  String get previousPageTooltip => data.label('previousPageTooltip');
  @override
  String get refreshIndicatorSemanticLabel =>
      data.label('refreshIndicatorSemanticLabel');
  @override
  String? get remainingTextFieldCharacterCountOne =>
      data.label('remainingTextFieldCharacterCountOne');
  @override
  String get remainingTextFieldCharacterCountOther =>
      data.label('remainingTextFieldCharacterCountOther');
  @override
  String? get remainingTextFieldCharacterCountZero =>
      data.label('remainingTextFieldCharacterCountZero');
  @override
  String get reorderItemDown => data.label('reorderItemDown');
  @override
  String get reorderItemLeft => data.label('reorderItemLeft');
  @override
  String get reorderItemRight => data.label('reorderItemRight');
  @override
  String get reorderItemToEnd => data.label('reorderItemToEnd');
  @override
  String get reorderItemToStart => data.label('reorderItemToStart');
  @override
  String get reorderItemUp => data.label('reorderItemUp');
  @override
  String get rowsPerPageTitle => data.label('rowsPerPageTitle');
  @override
  String get saveButtonLabel => data.label('saveButtonLabel');
  @override
  String get scanTextButtonLabel => data.label('scanTextButtonLabel');
  @override
  String get scrimLabel => data.label('scrimLabel');
  @override
  String get scrimOnTapHintRaw => data.label('scrimOnTapHintRaw');
  @override
  String get searchFieldLabel => data.label('searchFieldLabel');
  @override
  String get searchWebButtonLabel => data.label('searchWebButtonLabel');
  @override
  String get selectAllButtonLabel => data.label('selectAllButtonLabel');
  @override
  String get selectYearSemanticsLabel => data.label('selectYearSemanticsLabel');
  @override
  String get selectedDateLabel => data.label('selectedDateLabel');
  @override
  String? get selectedRowCountTitleOne =>
      data.label('selectedRowCountTitleOne');
  @override
  String get selectedRowCountTitleOther =>
      data.label('selectedRowCountTitleOther');
  @override
  String? get selectedRowCountTitleZero =>
      data.label('selectedRowCountTitleZero');
  @override
  String get shareButtonLabel => data.label('shareButtonLabel');
  @override
  String get showAccountsLabel => data.label('showAccountsLabel');
  @override
  String get showMenuTooltip => data.label('showMenuTooltip');
  @override
  String get signedInLabel => data.label('signedInLabel');
  @override
  String get tabLabelRaw => data.label('tabLabelRaw');
  @override
  String get timePickerDialHelpText => data.label('timePickerDialHelpText');
  @override
  String get timePickerHourLabel => data.label('timePickerHourLabel');
  @override
  String get timePickerHourModeAnnouncement =>
      data.label('timePickerHourModeAnnouncement');
  @override
  String get timePickerInputHelpText => data.label('timePickerInputHelpText');
  @override
  String get timePickerMinuteLabel => data.label('timePickerMinuteLabel');
  @override
  String get timePickerMinuteModeAnnouncement =>
      data.label('timePickerMinuteModeAnnouncement');
  @override
  String get unspecifiedDate => data.label('unspecifiedDate');
  @override
  String get unspecifiedDateRange => data.label('unspecifiedDateRange');
  @override
  String get viewLicensesButtonLabel => data.label('viewLicensesButtonLabel');
}

class _SupplementalCupertino extends CupertinoLocalizationEn {
  _SupplementalCupertino(this.data)
      : super(
          localeName: data.localeName,
          fullYearFormat: DateFormat.y(data.localeName),
          dayFormat: DateFormat.d(data.localeName),
          weekdayFormat: DateFormat.EEEE(data.localeName),
          mediumDateFormat: DateFormat.MMMEd(data.localeName),
          singleDigitHourFormat: DateFormat('h', data.localeName),
          singleDigitMinuteFormat: DateFormat.m(data.localeName),
          doubleDigitMinuteFormat: DateFormat('mm', data.localeName),
          singleDigitSecondFormat: DateFormat.s(data.localeName),
          decimalFormat: NumberFormat.decimalPattern(data.localeName),
        );
  final SupplementalLocaleData data;
  @override
  String get datePickerDateOrderString => data.dateOrder;
  @override
  String get datePickerDateTimeOrderString => 'date_time_dayPeriod';
  @override
  String get alertDialogLabel => data.label('alertDialogLabel');
  @override
  String get anteMeridiemAbbreviation => data.label('anteMeridiemAbbreviation');
  @override
  String get backButtonLabel => data.label('backButtonLabel');
  @override
  String get cancelButtonLabel => data.label('cancelButtonLabel');
  @override
  String get clearButtonLabel => data.label('clearButtonLabel');
  @override
  String get collapsedHint => data.label('collapsedHint');
  @override
  String get copyButtonLabel => data.label('copyButtonLabel');
  @override
  String get cutButtonLabel => data.label('cutButtonLabel');
  @override
  String? get datePickerHourSemanticsLabelOne =>
      data.label('datePickerHourSemanticsLabelOne');
  @override
  String get datePickerHourSemanticsLabelOther =>
      data.label('datePickerHourSemanticsLabelOther');
  @override
  String? get datePickerMinuteSemanticsLabelOne =>
      data.label('datePickerMinuteSemanticsLabelOne');
  @override
  String get datePickerMinuteSemanticsLabelOther =>
      data.label('datePickerMinuteSemanticsLabelOther');
  @override
  String get expandedHint => data.label('expandedHint');
  @override
  String get expansionTileCollapsedHint =>
      data.label('expansionTileCollapsedHint');
  @override
  String get expansionTileCollapsedTapHint =>
      data.label('expansionTileCollapsedTapHint');
  @override
  String get expansionTileExpandedHint =>
      data.label('expansionTileExpandedHint');
  @override
  String get expansionTileExpandedTapHint =>
      data.label('expansionTileExpandedTapHint');
  @override
  String get lookUpButtonLabel => data.label('lookUpButtonLabel');
  @override
  String get menuDismissLabel => data.label('menuDismissLabel');
  @override
  String get modalBarrierDismissLabel => data.label('modalBarrierDismissLabel');
  @override
  String get noSpellCheckReplacementsLabel =>
      data.label('noSpellCheckReplacementsLabel');
  @override
  String get pasteButtonLabel => data.label('pasteButtonLabel');
  @override
  String get postMeridiemAbbreviation => data.label('postMeridiemAbbreviation');
  @override
  String get searchTextFieldPlaceholderLabel =>
      data.label('searchTextFieldPlaceholderLabel');
  @override
  String get searchWebButtonLabel => data.label('searchWebButtonLabel');
  @override
  String get selectAllButtonLabel => data.label('selectAllButtonLabel');
  @override
  String get shareButtonLabel => data.label('shareButtonLabel');
  @override
  String get tabSemanticsLabelRaw => data.label('tabSemanticsLabelRaw');
  @override
  String? get timerPickerHourLabelOne => data.label('timerPickerHourLabelOne');
  @override
  String get timerPickerHourLabelOther =>
      data.label('timerPickerHourLabelOther');
  @override
  String? get timerPickerMinuteLabelOne =>
      data.label('timerPickerMinuteLabelOne');
  @override
  String get timerPickerMinuteLabelOther =>
      data.label('timerPickerMinuteLabelOther');
  @override
  String? get timerPickerSecondLabelOne =>
      data.label('timerPickerSecondLabelOne');
  @override
  String get timerPickerSecondLabelOther =>
      data.label('timerPickerSecondLabelOther');
  @override
  String get todayLabel => data.label('todayLabel');
}

const _requiredLabels = <String>{
  'aboutListTileTitleRaw',
  'alertDialogLabel',
  'anteMeridiemAbbreviation',
  'backButtonLabel',
  'backButtonTooltip',
  'bottomSheetLabel',
  'calendarModeButtonLabel',
  'cancelButtonLabel',
  'clearButtonLabel',
  'clearButtonTooltip',
  'closeButtonLabel',
  'closeButtonTooltip',
  'collapsedHint',
  'collapsedIconTapHint',
  'continueButtonLabel',
  'copyButtonLabel',
  'currentDateLabel',
  'cutButtonLabel',
  'dateInputLabel',
  'dateOutOfRangeLabel',
  'datePickerHelpText',
  'datePickerHourSemanticsLabelOne',
  'datePickerHourSemanticsLabelOther',
  'datePickerMinuteSemanticsLabelOne',
  'datePickerMinuteSemanticsLabelOther',
  'dateRangeEndDateSemanticLabelRaw',
  'dateRangeEndLabel',
  'dateRangePickerHelpText',
  'dateRangeStartDateSemanticLabelRaw',
  'dateRangeStartLabel',
  'dateSeparator',
  'deleteButtonTooltip',
  'dialModeButtonLabel',
  'dialogLabel',
  'drawerLabel',
  'expandedHint',
  'expandedIconTapHint',
  'expansionTileCollapsedHint',
  'expansionTileCollapsedTapHint',
  'expansionTileExpandedHint',
  'expansionTileExpandedTapHint',
  'firstPageTooltip',
  'hideAccountsLabel',
  'inputDateModeButtonLabel',
  'inputTimeModeButtonLabel',
  'invalidDateFormatLabel',
  'invalidDateRangeLabel',
  'invalidTimeLabel',
  'keyboardKeyAlt',
  'keyboardKeyAltGraph',
  'keyboardKeyBackspace',
  'keyboardKeyCapsLock',
  'keyboardKeyChannelDown',
  'keyboardKeyChannelUp',
  'keyboardKeyControl',
  'keyboardKeyDelete',
  'keyboardKeyEject',
  'keyboardKeyEnd',
  'keyboardKeyEscape',
  'keyboardKeyFn',
  'keyboardKeyHome',
  'keyboardKeyInsert',
  'keyboardKeyMeta',
  'keyboardKeyMetaMacOs',
  'keyboardKeyMetaWindows',
  'keyboardKeyNumLock',
  'keyboardKeyNumpad0',
  'keyboardKeyNumpad1',
  'keyboardKeyNumpad2',
  'keyboardKeyNumpad3',
  'keyboardKeyNumpad4',
  'keyboardKeyNumpad5',
  'keyboardKeyNumpad6',
  'keyboardKeyNumpad7',
  'keyboardKeyNumpad8',
  'keyboardKeyNumpad9',
  'keyboardKeyNumpadAdd',
  'keyboardKeyNumpadComma',
  'keyboardKeyNumpadDecimal',
  'keyboardKeyNumpadDivide',
  'keyboardKeyNumpadEnter',
  'keyboardKeyNumpadEqual',
  'keyboardKeyNumpadMultiply',
  'keyboardKeyNumpadParenLeft',
  'keyboardKeyNumpadParenRight',
  'keyboardKeyNumpadSubtract',
  'keyboardKeyPageDown',
  'keyboardKeyPageUp',
  'keyboardKeyPower',
  'keyboardKeyPowerOff',
  'keyboardKeyPrintScreen',
  'keyboardKeyScrollLock',
  'keyboardKeySelect',
  'keyboardKeyShift',
  'keyboardKeySpace',
  'lastPageTooltip',
  'licensesPackageDetailTextOne',
  'licensesPackageDetailTextOther',
  'licensesPackageDetailTextZero',
  'licensesPageTitle',
  'lookUpButtonLabel',
  'menuBarMenuLabel',
  'menuDismissLabel',
  'modalBarrierDismissLabel',
  'moreButtonTooltip',
  'nextMonthTooltip',
  'nextPageTooltip',
  'noSpellCheckReplacementsLabel',
  'okButtonLabel',
  'openAppDrawerTooltip',
  'pageRowsInfoTitleApproximateRaw',
  'pageRowsInfoTitleRaw',
  'pasteButtonLabel',
  'popupMenuLabel',
  'postMeridiemAbbreviation',
  'previousMonthTooltip',
  'previousPageTooltip',
  'refreshIndicatorSemanticLabel',
  'remainingTextFieldCharacterCountOne',
  'remainingTextFieldCharacterCountOther',
  'remainingTextFieldCharacterCountZero',
  'reorderItemDown',
  'reorderItemLeft',
  'reorderItemRight',
  'reorderItemToEnd',
  'reorderItemToStart',
  'reorderItemUp',
  'rowsPerPageTitle',
  'saveButtonLabel',
  'scanTextButtonLabel',
  'scrimLabel',
  'scrimOnTapHintRaw',
  'searchFieldLabel',
  'searchTextFieldPlaceholderLabel',
  'searchWebButtonLabel',
  'selectAllButtonLabel',
  'selectYearSemanticsLabel',
  'selectedDateLabel',
  'selectedRowCountTitleOne',
  'selectedRowCountTitleOther',
  'selectedRowCountTitleZero',
  'shareButtonLabel',
  'showAccountsLabel',
  'showMenuTooltip',
  'signedInLabel',
  'tabLabelRaw',
  'tabSemanticsLabelRaw',
  'timePickerDialHelpText',
  'timePickerHourLabel',
  'timePickerHourModeAnnouncement',
  'timePickerInputHelpText',
  'timePickerMinuteLabel',
  'timePickerMinuteModeAnnouncement',
  'timerPickerHourLabelOne',
  'timerPickerHourLabelOther',
  'timerPickerMinuteLabelOne',
  'timerPickerMinuteLabelOther',
  'timerPickerSecondLabelOne',
  'timerPickerSecondLabelOther',
  'todayLabel',
  'unspecifiedDate',
  'unspecifiedDateRange',
  'viewLicensesButtonLabel',
};
