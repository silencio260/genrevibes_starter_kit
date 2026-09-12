import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config keys for what Back does on the app's root screen.
///
/// Values are the `wireName`s of `ExitPromptStyle` and `ExitButtonEmphasis` in
/// `genrevibes_exit_prompt`, so an A/B test in Firebase is a different string
/// per variant.
abstract final class ExitPromptPolicyKeys {
  static const _string = RemoteConfigStringCodec();

  /// The values [style] accepts.
  static const styleNames = <String>{
    'ad_sheet',
    'ad_dialog',
    'features_sheet',
    'offer_sheet',
    'confirm_dialog',
    'double_tap',
    'none',
  };

  /// The values [exitButton] accepts.
  static const exitButtonNames = <String>{'standard', 'dimmed'};

  static bool _isStyle(String value) => styleNames.contains(value.trim());

  static bool _isExitButton(String value) =>
      exitButtonNames.contains(value.trim());

  /// The prompt style. A style missing what it needs, such as an ad for a
  /// premium user, falls back to `confirm_dialog`.
  ///
  /// Defaults to `features_sheet`, without an ad. Google Play's ads policy
  /// lists "Ads that are triggered by the home button or other features
  /// explicitly designed for exiting the app", so `ad_sheet` and `ad_dialog`
  /// are for deliberate tests, not the default.
  static const style = RemoteConfigKey<String>(
    name: 'exit_prompt_style',
    defaultValue: 'features_sheet',
    codec: _string,
    isValid: _isStyle,
  );

  /// How the Exit button looks: `standard` or `dimmed`.
  static const exitButton = RemoteConfigKey<String>(
    name: 'exit_prompt_exit_button',
    defaultValue: 'standard',
    codec: _string,
    isValid: _isExitButton,
  );

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(style),
        remoteConfigKey(exitButton),
      ];
}
