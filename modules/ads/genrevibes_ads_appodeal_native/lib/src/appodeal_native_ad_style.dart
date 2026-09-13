import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How the Android native ad view arranges an ad.
enum AppodealNativeAdLayout {
  /// Icon and title, body, media, and a full-width call to action.
  medium,

  /// Icon and title, body, and a full-width call to action. No media.
  small,

  /// One row: the icon, the attribution badge and headline above one line of
  /// body, and the call to action at the end. No media, and no top strip:
  /// roughly a third of the height of [small].
  compact,
}

/// The look of an `AppodealNativeAdView`.
///
/// Sizes are logical pixels and font sizes are scaled pixels, as on Android.
/// The defaults match a white card with purple accents and a large rounded
/// call to action.
final class AppodealNativeAdStyle {
  /// Creates a style.
  const AppodealNativeAdStyle({
    this.layout = AppodealNativeAdLayout.medium,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.titleColor = const Color(0xFF6F42D8),
    this.bodyColor = const Color(0xFF202124),
    this.callToActionColor = const Color(0xFF7B4FE0),
    this.callToActionTextColor = const Color(0xFFFFFFFF),
    this.attributionColor = const Color(0xFF7B4FE0),
    this.attributionTextColor = const Color(0xFFFFFFFF),
    this.attributionLabel = 'Ad',
    this.cornerRadius = 0,
    this.callToActionCornerRadius = 16,
    this.attributionStripHeight = 20,
    this.padding = 12,
    this.spacing = 8,
    this.iconSize = 56,
    this.mediaHeight = 180,
    this.callToActionHeight = 56,
    this.titleFontSize = 16,
    this.bodyFontSize = 14,
    this.callToActionFontSize = 22,
    this.height,
  });

  /// Whether media is shown.
  final AppodealNativeAdLayout layout;

  /// Card background.
  final Color backgroundColor;

  /// Headline text.
  final Color titleColor;

  /// Body text.
  final Color bodyColor;

  /// Call-to-action button.
  final Color callToActionColor;

  /// Call-to-action text.
  final Color callToActionTextColor;

  /// The attribution badge.
  final Color attributionColor;

  /// The attribution badge text.
  final Color attributionTextColor;

  /// The attribution badge label. Networks require the ad to be marked.
  final String attributionLabel;

  /// Card corner radius.
  final double cornerRadius;

  /// Call-to-action corner radius.
  final double callToActionCornerRadius;

  /// Height of the strip at the top of the card that holds the attribution
  /// badge and AdChoices, so neither covers the icon or the headline. Not used
  /// by [AppodealNativeAdLayout.compact], which puts the badge by the headline.
  final double attributionStripHeight;

  /// Space inside the card.
  final double padding;

  /// Space between rows.
  final double spacing;

  /// Icon width and height.
  final double iconSize;

  /// Media height, in the medium layout.
  final double mediaHeight;

  /// Call-to-action height.
  final double callToActionHeight;

  /// Headline font size.
  final double titleFontSize;

  /// Body font size.
  final double bodyFontSize;

  /// Call-to-action font size.
  final double callToActionFontSize;

  /// Fixed height for the view. Null derives it from the other sizes.
  final double? height;

  /// The height the Flutter view gives the native view.
  ///
  /// The body shows at most two lines, so this leaves room for two; the
  /// [AppodealNativeAdLayout.compact] row shows one.
  double get resolvedHeight {
    final fixed = height;
    if (fixed != null) return fixed;
    if (layout == AppodealNativeAdLayout.compact) {
      final text = titleFontSize * 1.4 + 2 + bodyFontSize * 1.4;
      return padding * 2 +
          math.max(iconSize, math.max(callToActionHeight, text));
    }
    final header = math.max(iconSize, titleFontSize * 1.4 * 2);
    final body = bodyFontSize * 1.4 * 2;
    final media =
        layout == AppodealNativeAdLayout.medium ? spacing + mediaHeight : 0;
    return padding * 2 +
        attributionStripHeight +
        spacing +
        header +
        spacing +
        body +
        media +
        spacing +
        callToActionHeight;
  }

  /// The parameters the Android view reads.
  Map<String, Object?> toCreationParams() => <String, Object?>{
        'layout': layout.name,
        'backgroundColor': backgroundColor.toARGB32(),
        'titleColor': titleColor.toARGB32(),
        'bodyColor': bodyColor.toARGB32(),
        'callToActionColor': callToActionColor.toARGB32(),
        'callToActionTextColor': callToActionTextColor.toARGB32(),
        'attributionColor': attributionColor.toARGB32(),
        'attributionTextColor': attributionTextColor.toARGB32(),
        'attributionLabel': attributionLabel,
        'cornerRadius': cornerRadius,
        'callToActionCornerRadius': callToActionCornerRadius,
        'attributionStripHeight': attributionStripHeight,
        'padding': padding,
        'spacing': spacing,
        'iconSize': iconSize,
        'mediaHeight': mediaHeight,
        'callToActionHeight': callToActionHeight,
        'titleFontSize': titleFontSize,
        'bodyFontSize': bodyFontSize,
        'callToActionFontSize': callToActionFontSize,
      };
}
