package com.genrevibes.ads_appodeal_native;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.appodeal.ads.NativeAd;
import com.appodeal.ads.nativead.NativeAdView;
import com.appodeal.ads.nativead.NativeIconView;
import com.appodeal.ads.nativead.NativeMediaView;
import com.appodeal.ads.nativead.Position;

/**
 * Builds a native ad card: icon and headline, body, optional media, a full-width call to action,
 * and a strip above them holding the attribution badge at the start and AdChoices at the end.
 *
 * <p>Every asset view is handed to the {@link NativeAdView}, which is what lets the SDK and the
 * winning network track the impression and the click.
 */
final class NativeAdTemplate {
  private NativeAdTemplate() {}

  static NativeAdView build(Context context, NativeAdStyle style, NativeAd ad) {
    if (style.compact) return buildCompact(context, style, ad);
    final NativeAdView adView = new NativeAdView(context);

    final LinearLayout card = new LinearLayout(context);
    card.setOrientation(LinearLayout.VERTICAL);
    card.setPadding(style.padding, style.padding, style.padding, style.padding);
    card.setBackground(roundRect(style.backgroundColor, style.cornerRadius));

    // The attribution badge and AdChoices get their own strip at the top of the card. Drawn over
    // its corners, the badge covered the icon and AdChoices could cover the headline.
    final FrameLayout strip = new FrameLayout(context);
    card.addView(
        strip,
        new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, style.attributionStripHeight));

    final NativeIconView icon = new NativeIconView(context);
    final TextView title =
        text(context, ad.getTitle(), style.titleColor, style.titleFontSize, true, 2);
    final LinearLayout header = new LinearLayout(context);
    header.setOrientation(LinearLayout.HORIZONTAL);
    header.setGravity(Gravity.CENTER_VERTICAL);
    header.addView(icon, new LinearLayout.LayoutParams(style.iconSize, style.iconSize));
    final LinearLayout.LayoutParams titleParams =
        new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
    titleParams.setMarginStart(style.spacing);
    header.addView(title, titleParams);
    card.addView(header, matchWidth(style.spacing));

    final TextView body =
        text(context, ad.getDescription(), style.bodyColor, style.bodyFontSize, false, 2);
    card.addView(body, matchWidth(style.spacing));

    NativeMediaView media = null;
    if (style.showMedia) {
      media = new NativeMediaView(context);
      final LinearLayout.LayoutParams mediaParams =
          new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, style.mediaHeight);
      mediaParams.topMargin = style.spacing;
      card.addView(media, mediaParams);
    }

    final TextView callToAction =
        text(
            context,
            ad.getCallToAction(),
            style.callToActionTextColor,
            style.callToActionFontSize,
            false,
            1);
    callToAction.setGravity(Gravity.CENTER);
    callToAction.setBackground(
        roundRect(style.callToActionColor, style.callToActionCornerRadius));
    final LinearLayout.LayoutParams callToActionParams =
        new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, style.callToActionHeight);
    callToActionParams.topMargin = style.spacing;
    card.addView(callToAction, callToActionParams);

    adView.addView(
        card,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

    final TextView attribution = attributionBadge(context, style);
    strip.addView(
        attribution,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER_VERTICAL | Gravity.START));

    final FrameLayout adChoices = new FrameLayout(context);
    strip.addView(
        adChoices,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER_VERTICAL | Gravity.END));

    adView.setTitleView(title);
    adView.setDescriptionView(body);
    adView.setCallToActionView(callToAction);
    adView.setIconView(icon);
    if (media != null) adView.setMediaView(media);
    adView.setAdAttributionView(attribution);
    adView.setAdChoiceView(adChoices);
    adView.setAdAttributionBackground(style.attributionColor);
    adView.setAdAttributionTextColor(style.attributionTextColor);
    adView.setAdChoicesPosition(Position.END_TOP);
    return adView;
  }

  /**
   * One row: the icon, then the attribution badge and headline above one line of body, then the
   * call to action. AdChoices sits in the top-end corner. No media.
   */
  private static NativeAdView buildCompact(Context context, NativeAdStyle style, NativeAd ad) {
    final NativeAdView adView = new NativeAdView(context);
    final float density = context.getResources().getDisplayMetrics().density;

    final LinearLayout card = new LinearLayout(context);
    card.setOrientation(LinearLayout.HORIZONTAL);
    card.setGravity(Gravity.CENTER_VERTICAL);
    card.setPadding(style.padding, style.padding, style.padding, style.padding);
    card.setBackground(roundRect(style.backgroundColor, style.cornerRadius));

    final NativeIconView icon = new NativeIconView(context);
    card.addView(icon, new LinearLayout.LayoutParams(style.iconSize, style.iconSize));

    final LinearLayout texts = new LinearLayout(context);
    texts.setOrientation(LinearLayout.VERTICAL);
    final LinearLayout.LayoutParams textsParams =
        new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
    textsParams.setMarginStart(style.spacing);
    textsParams.setMarginEnd(style.spacing);
    card.addView(texts, textsParams);

    final LinearLayout headline = new LinearLayout(context);
    headline.setOrientation(LinearLayout.HORIZONTAL);
    headline.setGravity(Gravity.CENTER_VERTICAL);
    texts.addView(headline, matchWidth(0));

    final TextView attribution = attributionBadge(context, style);
    headline.addView(
        attribution,
        new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

    final TextView title =
        text(context, ad.getTitle(), style.titleColor, style.titleFontSize, true, 1);
    final LinearLayout.LayoutParams titleParams =
        new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
    titleParams.setMarginStart(Math.round(6 * density));
    headline.addView(title, titleParams);

    final TextView body =
        text(context, ad.getDescription(), style.bodyColor, style.bodyFontSize, false, 1);
    texts.addView(body, matchWidth(Math.round(2 * density)));

    final TextView callToAction =
        text(
            context,
            ad.getCallToAction(),
            style.callToActionTextColor,
            style.callToActionFontSize,
            false,
            1);
    callToAction.setGravity(Gravity.CENTER);
    final int horizontal = Math.round(14 * density);
    callToAction.setPadding(horizontal, 0, horizontal, 0);
    callToAction.setMinWidth(Math.round(72 * density));
    callToAction.setBackground(
        roundRect(style.callToActionColor, style.callToActionCornerRadius));
    card.addView(
        callToAction,
        new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, style.callToActionHeight));

    adView.addView(
        card,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

    final FrameLayout adChoices = new FrameLayout(context);
    adView.addView(
        adChoices,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP | Gravity.END));

    adView.setTitleView(title);
    adView.setDescriptionView(body);
    adView.setCallToActionView(callToAction);
    adView.setIconView(icon);
    adView.setAdAttributionView(attribution);
    adView.setAdChoiceView(adChoices);
    adView.setAdAttributionBackground(style.attributionColor);
    adView.setAdAttributionTextColor(style.attributionTextColor);
    adView.setAdChoicesPosition(Position.END_TOP);
    return adView;
  }

  /** The "Ad" badge. Networks require the ad to be marked. */
  private static TextView attributionBadge(Context context, NativeAdStyle style) {
    final TextView attribution = new TextView(context);
    attribution.setText(style.attributionLabel);
    attribution.setTextSize(11);
    attribution.setTypeface(Typeface.DEFAULT_BOLD);
    attribution.setIncludeFontPadding(false);
    final int badge = Math.round(6 * context.getResources().getDisplayMetrics().density);
    attribution.setPadding(badge, badge / 3, badge, badge / 3);
    return attribution;
  }

  private static TextView text(
      Context context, String value, int color, float size, boolean bold, int maxLines) {
    final TextView view = new TextView(context);
    view.setText(value);
    view.setTextColor(color);
    view.setTextSize(size);
    view.setMaxLines(maxLines);
    view.setEllipsize(TextUtils.TruncateAt.END);
    if (bold) view.setTypeface(Typeface.DEFAULT_BOLD);
    return view;
  }

  private static GradientDrawable roundRect(int color, float radius) {
    final GradientDrawable drawable = new GradientDrawable();
    drawable.setColor(color);
    drawable.setCornerRadius(radius);
    return drawable;
  }

  private static LinearLayout.LayoutParams matchWidth(int topMargin) {
    final LinearLayout.LayoutParams params =
        new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    params.topMargin = topMargin;
    return params;
  }
}
