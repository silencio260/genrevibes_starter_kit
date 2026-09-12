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
 * the attribution badge top-left and AdChoices top-right.
 *
 * <p>Every asset view is handed to the {@link NativeAdView}, which is what lets the SDK and the
 * winning network track the impression and the click.
 */
final class NativeAdTemplate {
  private NativeAdTemplate() {}

  static NativeAdView build(Context context, NativeAdStyle style, NativeAd ad) {
    final NativeAdView adView = new NativeAdView(context);

    final LinearLayout card = new LinearLayout(context);
    card.setOrientation(LinearLayout.VERTICAL);
    card.setPadding(style.padding, style.padding, style.padding, style.padding);
    card.setBackground(roundRect(style.backgroundColor, style.cornerRadius));

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
    card.addView(header, matchWidth(0));

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

    final TextView attribution = new TextView(context);
    attribution.setText(style.attributionLabel);
    attribution.setTextSize(11);
    attribution.setTypeface(Typeface.DEFAULT_BOLD);
    final int badge = Math.round(6 * context.getResources().getDisplayMetrics().density);
    attribution.setPadding(badge, badge / 3, badge, badge / 3);
    adView.addView(
        attribution,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP | Gravity.START));

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
    if (media != null) adView.setMediaView(media);
    adView.setAdAttributionView(attribution);
    adView.setAdChoiceView(adChoices);
    adView.setAdAttributionBackground(style.attributionColor);
    adView.setAdAttributionTextColor(style.attributionTextColor);
    adView.setAdChoicesPosition(Position.END_TOP);
    return adView;
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
