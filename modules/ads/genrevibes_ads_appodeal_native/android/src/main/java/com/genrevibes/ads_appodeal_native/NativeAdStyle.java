package com.genrevibes.ads_appodeal_native;

import android.content.Context;
import java.util.Map;

/** The look of a native ad view, read from the Flutter view's creation parameters. */
final class NativeAdStyle {
  final boolean compact;
  final boolean showMedia;
  final int backgroundColor;
  final int titleColor;
  final int bodyColor;
  final int callToActionColor;
  final int callToActionTextColor;
  final int attributionColor;
  final int attributionTextColor;
  final String attributionLabel;
  final float cornerRadius;
  final float callToActionCornerRadius;
  final int attributionStripHeight;
  final int padding;
  final int spacing;
  final int iconSize;
  final int mediaHeight;
  final int callToActionHeight;
  final float titleFontSize;
  final float bodyFontSize;
  final float callToActionFontSize;

  private NativeAdStyle(Map<?, ?> args, float density) {
    final Object layout = args.get("layout");
    compact = "compact".equals(layout);
    showMedia = !compact && !"small".equals(layout);
    backgroundColor = color(args, "backgroundColor", 0xFFFFFFFF);
    titleColor = color(args, "titleColor", 0xFF6F42D8);
    bodyColor = color(args, "bodyColor", 0xFF202124);
    callToActionColor = color(args, "callToActionColor", 0xFF7B4FE0);
    callToActionTextColor = color(args, "callToActionTextColor", 0xFFFFFFFF);
    attributionColor = color(args, "attributionColor", 0xFF7B4FE0);
    attributionTextColor = color(args, "attributionTextColor", 0xFFFFFFFF);
    final Object label = args.get("attributionLabel");
    attributionLabel = label instanceof String ? (String) label : "Ad";
    cornerRadius = (float) number(args, "cornerRadius", 0) * density;
    callToActionCornerRadius = (float) number(args, "callToActionCornerRadius", 16) * density;
    attributionStripHeight = pixels(args, "attributionStripHeight", 20, density);
    padding = pixels(args, "padding", 12, density);
    spacing = pixels(args, "spacing", 8, density);
    iconSize = pixels(args, "iconSize", 56, density);
    mediaHeight = pixels(args, "mediaHeight", 180, density);
    callToActionHeight = pixels(args, "callToActionHeight", 56, density);
    titleFontSize = (float) number(args, "titleFontSize", 16);
    bodyFontSize = (float) number(args, "bodyFontSize", 14);
    callToActionFontSize = (float) number(args, "callToActionFontSize", 22);
  }

  static NativeAdStyle from(Map<?, ?> args, Context context) {
    return new NativeAdStyle(args, context.getResources().getDisplayMetrics().density);
  }

  // Colors arrive as ARGB values, a Long when above Integer.MAX_VALUE; the low 32 bits are the color.
  private static int color(Map<?, ?> args, String key, int fallback) {
    final Object value = args.get(key);
    return value instanceof Number ? (int) ((Number) value).longValue() : fallback;
  }

  private static double number(Map<?, ?> args, String key, double fallback) {
    final Object value = args.get(key);
    return value instanceof Number ? ((Number) value).doubleValue() : fallback;
  }

  private static int pixels(Map<?, ?> args, String key, double fallback, float density) {
    return Math.round((float) number(args, key, fallback) * density);
  }
}
