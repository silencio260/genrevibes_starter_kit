import 'package:flutter/widgets.dart';

import 'appodeal_native_ad_style.dart';

/// A quiet stand-in with the size, colors and shape of an
/// `AppodealNativeAdView`, for the space a screen keeps for an ad before one
/// loads.
///
/// It shows soft blocks where the icon, headline, body, media and call to
/// action will be, and no text: it must not read as an ad or as content, and it
/// takes no taps. Pass it as the view's `placeholder`, inside a space the
/// height of [AppodealNativeAdStyle.resolvedHeight], and the ad replaces it
/// without anything around it moving.
final class AppodealNativeAdPlaceholder extends StatelessWidget {
  /// Creates a placeholder shaped like an ad drawn with [style].
  const AppodealNativeAdPlaceholder({
    super.key,
    this.style = const AppodealNativeAdStyle(),
    this.blockColor,
  });

  /// The style of the ad this stands in for.
  final AppodealNativeAdStyle style;

  /// The blocks' color. Defaults to a shade darker than the card.
  final Color? blockColor;

  @override
  Widget build(BuildContext context) {
    final block = blockColor ??
        Color.alphaBlend(const Color(0x14000000), style.backgroundColor);

    Widget shape(double height, {double? width, double radius = 4}) =>
        Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          width: double.infinity,
          height: style.resolvedHeight,
          padding: EdgeInsets.all(style.padding),
          decoration: BoxDecoration(
            color: style.backgroundColor,
            borderRadius: BorderRadius.circular(style.cornerRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  shape(style.iconSize, width: style.iconSize, radius: 8),
                  SizedBox(width: style.spacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        shape(style.titleFontSize, width: 160),
                        const SizedBox(height: 6),
                        shape(style.titleFontSize * 0.8, width: 90),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: style.spacing),
              shape(style.bodyFontSize),
              const SizedBox(height: 6),
              shape(style.bodyFontSize, width: 220),
              if (style.layout == AppodealNativeAdLayout.medium) ...<Widget>[
                SizedBox(height: style.spacing),
                shape(style.mediaHeight),
              ],
              const Spacer(),
              shape(
                style.callToActionHeight,
                radius: style.callToActionCornerRadius,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
