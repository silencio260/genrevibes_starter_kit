/// The consent signals a consent platform stored for ad SDKs to read.
///
/// These are the IAB Transparency and Consent Framework v2 and Global Privacy
/// Platform values, stored under standard keys (`IABTCF_*`, `IABGPP_*`) in the
/// app's default preferences. Ad SDKs, and every network they mediate, read
/// them from there; the application never passes them along itself.
///
/// Outside a regulated region the platform's next consent update overwrites
/// them, so a TC string from a simulated-region preview does not survive it.
final class ConsentSignals {
  /// Creates signals from the stored values, by key.
  const ConsentSignals(this.values);

  /// Every stored `IABTCF_` and `IABGPP_` value, by key.
  final Map<String, Object?> values;

  /// Whether GDPR applies to this user (`IABTCF_gdprApplies`), or null when
  /// the platform has not decided.
  bool? get gdprApplies => switch (values['IABTCF_gdprApplies']) {
        final int applies => applies == 1,
        _ => null,
      };

  /// The TC string ad SDKs read (`IABTCF_TCString`), or null when none is
  /// stored.
  String? get tcString => _text('IABTCF_TCString');

  /// Consent per IAB purpose, one digit each from purpose 1
  /// (`IABTCF_PurposeConsents`).
  String? get purposeConsents => _text('IABTCF_PurposeConsents');

  /// Google's Additional Consent string, for vendors outside the IAB list
  /// (`IABTCF_AddtlConsent`).
  String? get additionalConsent => _text('IABTCF_AddtlConsent');

  /// The GPP string, for US state regulations (`IABGPP_HDR_GppString`).
  String? get gppString => _text('IABGPP_HDR_GppString');

  /// The GPP sections that apply (`IABGPP_GppSID`).
  String? get gppSectionIds => _text('IABGPP_GppSID');

  /// IAB-registered ID of the consent platform that wrote these
  /// (`IABTCF_CmpSdkID`); Google's is 300.
  int? get cmpSdkId => switch (values['IABTCF_CmpSdkID']) {
        final int id => id,
        _ => null,
      };

  String? _text(String key) => switch (values[key]) {
        final String value when value.isNotEmpty => value,
        _ => null,
      };

  @override
  String toString() => 'ConsentSignals(gdprApplies: $gdprApplies, '
      'tcString: ${tcString == null ? 'none' : '${tcString!.length} chars'}, '
      'purposeConsents: $purposeConsents, cmpSdkId: $cmpSdkId)';
}
