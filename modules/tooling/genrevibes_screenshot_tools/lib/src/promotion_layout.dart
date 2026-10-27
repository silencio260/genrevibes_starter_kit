import 'package:flutter/material.dart';

/// All wording remains editable; never put translated copy in backgroundArt.
class PromotionCopy {
  const PromotionCopy({required this.headline, this.caption = ''});

  final String headline;
  final String caption;
}

class PromotionStyle {
  const PromotionStyle({
    this.background = const Color(0xff061c20),
    this.accent = const Color(0xff76ebcd),
    this.foreground = Colors.white,
    this.muted = const Color(0xffb8d1cf),
    this.fontFamily,
    this.fontFamilyFallback,
    this.typography,
    this.backgroundArt,
  });

  final Color background;
  final Color accent;
  final Color foreground;
  final Color muted;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final TextStyle Function(FontWeight weight)? typography;

  /// Reusable text-free AI artwork, supplied by the host. No generation per locale.
  final ImageProvider? backgroundArt;
}

/// A real app widget at its own viewport, scaled into a decorative phone frame.
/// Keep the widget localized using the host's delegates and selected locale.
class PromotionPhone extends StatelessWidget {
  const PromotionPhone({
    super.key,
    required this.child,
    this.viewport = const Size(390, 844),
    this.frameColor = const Color(0xff172b31),
  });

  final Widget child;
  final Size viewport;
  final Color frameColor;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.contain,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: frameColor,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xff496369), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox.fromSize(
                size: viewport,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: viewport,
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewInsets: EdgeInsets.zero,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Default editable composition. Apps may supply another widget composition.
class PromotionLayout extends StatelessWidget {
  const PromotionLayout({
    super.key,
    required this.brand,
    required this.copy,
    required this.style,
    this.screen,
    this.featureGraphic = false,
  });

  final String brand;
  final PromotionCopy copy;
  final PromotionStyle style;
  final Widget? screen;
  final bool featureGraphic;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditablePromotionText(
          brand,
          maxLines: 1,
          minSize: 10,
          maxSize: 12,
          style: _textStyle(style.accent, FontWeight.w700),
        ),
        const SizedBox(height: 12),
        EditablePromotionText(
          copy.headline,
          maxLines: featureGraphic ? 3 : 2,
          minSize: featureGraphic ? 20 : 24,
          maxSize: featureGraphic ? 34 : 36,
          style: _textStyle(style.foreground, FontWeight.w800),
        ),
        if (copy.caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          EditablePromotionText(
            copy.caption,
            maxLines: 3,
            minSize: 10,
            maxSize: 13,
            style: _textStyle(style.muted, FontWeight.w400),
          ),
        ],
      ],
    );
    final phone = screen == null ? null : PromotionPhone(child: screen!);
    return Material(
      color: style.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (style.backgroundArt != null)
            Image(image: style.backgroundArt!, fit: BoxFit.cover),
          if (style.backgroundArt != null)
            ColoredBox(color: style.background.withValues(alpha: .65)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: featureGraphic
                ? Row(
                    children: [
                      Expanded(flex: 3, child: Center(child: text)),
                      if (phone != null) ...[
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: phone),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      text,
                      const SizedBox(height: 20),
                      if (phone != null) Expanded(child: phone),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  TextStyle _textStyle(Color color, FontWeight weight) =>
      (style.typography?.call(weight) ??
              TextStyle(fontFamily: style.fontFamily))
          .copyWith(
        color: color,
        fontWeight: weight,
        fontFamilyFallback: style.fontFamilyFallback,
        height: 1.12,
      );
}

/// Fits translated text without ellipsis. Fails if the minimum readable size
/// still cannot contain it, rather than exporting clipped marketing copy.
class EditablePromotionText extends StatelessWidget {
  const EditablePromotionText(
    this.text, {
    super.key,
    required this.style,
    required this.maxLines,
    this.minSize = 12,
    this.maxSize = 36,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minSize;
  final double maxSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final direction = Directionality.of(context);
          final locale = Localizations.maybeLocaleOf(context);
          // Text normally merges inherited spacing and typography. Measure that
          // exact style, then paint the same span instead of merging it again.
          final effectiveStyle =
              DefaultTextStyle.of(context).style.merge(style);
          var size = maxSize;
          final painter = TextPainter(
            textDirection: direction,
            locale: locale,
            maxLines: maxLines,
          );
          try {
            while (true) {
              painter.text = TextSpan(
                  text: text, style: effectiveStyle.copyWith(fontSize: size));
              painter.layout(maxWidth: constraints.maxWidth);
              if (!painter.didExceedMaxLines &&
                  (maxLines != 1 ||
                      painter.maxIntrinsicWidth <= constraints.maxWidth) &&
                  (!constraints.hasBoundedHeight ||
                      painter.height <= constraints.maxHeight)) {
                break;
              }
              if (size <= minSize) {
                throw FlutterError('Promotional text does not fit: "$text". '
                    'Shorten the translation or adjust the editable layout.');
              }
              size = (size - 1).clamp(minSize, maxSize);
            }
          } finally {
            painter.dispose();
          }
          return RichText(
            text: TextSpan(
                text: text, style: effectiveStyle.copyWith(fontSize: size)),
            maxLines: maxLines,
            textDirection: direction,
            locale: locale,
            textScaler: TextScaler.noScaling,
          );
        },
      );
}
