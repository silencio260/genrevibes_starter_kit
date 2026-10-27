import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'locale_tag.dart';
import 'localization_configuration.dart';
import 'localization_preferences.dart';

/// One instance per app runtime. All writes are serialized, local-first, and
/// reported through KitResult. Profile synchronization belongs to the host.
class LocalizationController extends ChangeNotifier
    with WidgetsBindingObserver {
  LocalizationController(
      {required this.configuration,
      required KeyValueStore store,
      List<Locale>? deviceLocales})
      : _store = store,
        _deviceLocales = List.of(deviceLocales ??
            WidgetsBinding.instance.platformDispatcher.locales);

  final LocalizationConfiguration configuration;
  final KeyValueStore _store;
  List<Locale> _deviceLocales;
  LocalizationPreferences _preferences = const LocalizationPreferences();
  Future<void> _writes = Future.value();
  bool _hasLocalChoice = false;
  bool _observing = false;
  bool _disposed = false;
  bool _saving = false;
  KitError? _lastError;

  LocalizationPreferences get preferences => _preferences;
  bool get hasLocalChoice => _hasLocalChoice;
  bool get isSaving => _saving;
  KitError? get lastError => _lastError;
  LocaleOption get effectiveOption => configuration.resolve(
        _preferences.localeTag == null
            ? _deviceLocales.map((locale) => LocaleTag.fromLocale(locale).tag)
            : [_preferences.localeTag!],
      );
  Locale get locale => effectiveOption.locale;
  String get effectiveTag => effectiveOption.tag;
  TextDirection get direction => effectiveOption.direction;
  String? get effectiveCountry {
    final picked = _preferences.countryCode;
    if (picked != null) return picked;
    for (final locale in _deviceLocales) {
      final code = locale.countryCode;
      if (configuration.countries.any((country) => country.code == code)) {
        return code;
      }
    }
    return null;
  }

  Locale get formattingLocale =>
      configuration.formattingLocale(effectiveOption, effectiveCountry);
  bool get usesFallback =>
      _preferences.localeTag != null &&
      configuration.exact(_preferences.localeTag) == null;

  void observeDeviceLocales() {
    if (_observing || _disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeLocales(List<Locale>? locales) =>
      updateDeviceLocales(locales ?? const []);

  void updateDeviceLocales(List<Locale> locales) {
    if (_disposed) return;
    _deviceLocales = List.of(locales);
    _notify();
  }

  Future<KitResult<void>> load(
      {LocalizationPreferences? legacyPreferences}) async {
    final result = await _store.getString(configuration.storageKey);
    if (_disposed) return _unavailable();
    if (result case KitFailure<String?>(:final error)) {
      _lastError = error;
      return KitFailure<void>(error);
    }
    final raw = (result as KitSuccess<String?>).value;
    if (raw != null) {
      try {
        final saved = LocalizationPreferences.fromJson(jsonDecode(raw));
        if (saved == null || !_validStored(saved)) {
          throw const FormatException('Invalid preferences');
        }
        _preferences = saved;
        _hasLocalChoice = true;
        _notify();
        return const KitSuccess(null);
      } on FormatException {
        _lastError = const KitError(
            code: KitErrorCode.invalidConfiguration,
            message: 'Stored localization preferences are invalid.');
        _notify();
        return KitFailure(_lastError!);
      }
    }
    if (legacyPreferences != null && _validStored(legacyPreferences)) {
      return _save(legacyPreferences);
    }
    _notify();
    return const KitSuccess(null);
  }

  bool _validStored(LocalizationPreferences prefs) =>
      (prefs.localeTag == null ||
          LocaleTag.tryParse(prefs.localeTag) != null) &&
      (prefs.countryCode == null ||
          configuration.countries
              .any((country) => country.code == prefs.countryCode));

  /// Seed an untouched device from its current account. A manual device choice,
  /// including an explicit reset to device language, always wins.
  void followProfile(LocalizationPreferences? prefs) {
    if (_disposed || _hasLocalChoice) return;
    _preferences = prefs != null && _validStored(prefs)
        ? prefs
        : const LocalizationPreferences();
    _notify();
  }

  Future<KitResult<void>> chooseLocale(String? tag) => _enqueue(() {
        final normalized = tag == null ? null : configuration.normalize(tag);
        if (tag != null && configuration.exact(normalized) == null) {
          return Future.value(_invalid());
        }
        return _save(LocalizationPreferences(
            localeTag: normalized, countryCode: _preferences.countryCode));
      });

  Future<KitResult<void>> chooseCountry(String? code) => _enqueue(() {
        if (code != null &&
            !configuration.countries.any((country) => country.code == code)) {
          return Future.value(_invalid());
        }
        return _save(LocalizationPreferences(
            localeTag: _preferences.localeTag, countryCode: code));
      });

  Future<KitResult<void>> _enqueue(
      Future<KitResult<void>> Function() operation) {
    final completer = Completer<KitResult<void>>();
    _writes = _writes.then((_) async {
      if (_disposed) {
        completer.complete(_unavailable());
        return;
      }
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        final failure = KitError(
            code: KitErrorCode.provider,
            message: 'Could not save localization preferences.',
            cause: error,
            stackTrace: stack);
        if (!_disposed) {
          _saving = false;
          _lastError = failure;
          _notify();
        }
        completer.complete(KitFailure<void>(failure));
      }
    });
    return completer.future;
  }

  Future<KitResult<void>> _save(LocalizationPreferences next) async {
    if (_disposed) return _unavailable();
    _saving = true;
    _lastError = null;
    _notify();
    final result = await _store.setString(
        configuration.storageKey, jsonEncode(next.toJson()));
    if (_disposed) return _unavailable();
    _saving = false;
    if (result case KitFailure<void>(:final error)) {
      _lastError = error;
    } else {
      _preferences = next;
      _hasLocalChoice = true;
    }
    _notify();
    return result;
  }

  KitResult<void> _invalid() => const KitFailure(KitError(
      code: KitErrorCode.invalidConfiguration,
      message: 'The requested locale or country is unavailable.'));
  KitResult<void> _unavailable() => const KitFailure(KitError(
      code: KitErrorCode.unavailable,
      message: 'Localization controller is disposed.'));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
