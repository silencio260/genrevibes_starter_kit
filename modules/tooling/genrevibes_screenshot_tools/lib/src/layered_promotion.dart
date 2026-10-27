import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Position visible text vertically within its registered panel.
enum PromotionTextVerticalAlignment { top, center, bottom }

/// A single replaceable text region, measured in the template's design pixels.
///
/// [rect] defines a normal text panel. When [quad] is supplied its four corners
/// (top-left, top-right, bottom-right, bottom-left) define that panel's projected
/// position on a photographed screen or floating card. Only the panel dimensions
/// are taken from [rect] in that case; the quadrilateral contains absolute design
/// coordinates. Text direction never mirrors or reorders those physical corners.
class PromotionTextLayer {
  const PromotionTextLayer({
    required this.id,
    required this.rect,
    required this.maxFontSize,
    required this.minFontSize,
    this.quad,
    this.color = Colors.white,
    this.weight = FontWeight.w400,
    this.maxLines = 1,
    this.alignment = TextAlign.start,
    this.verticalAlignment = PromotionTextVerticalAlignment.top,
    this.lineHeight = 1.1,
    this.direction,
    this.letterSpacing = 0,
    this.gradient,
    this.leadingIcon,
    this.iconSize = 24,
    this.iconGap = 8,
  });

  final String id;
  final Rect rect;
  final List<Offset>? quad;
  final double maxFontSize;
  final double minFontSize;
  final Color color;
  final FontWeight weight;
  final int maxLines;
  final TextAlign alignment;
  final PromotionTextVerticalAlignment verticalAlignment;
  final double lineHeight;
  final TextDirection? direction;
  final double letterSpacing;

  /// Optional icon rendered with the label as one aligned group. The host must
  /// remove or cover any corresponding icon already baked into the master.
  /// Icon groups require [prepareLayeredPromotionText] for exact glyph fitting.
  final IconData? leadingIcon;
  final double iconSize;
  final double iconGap;

  /// Optional top-to-bottom colors for a headline's original material treatment.
  final List<Color>? gradient;
}

/// Reuses a host-owned photographic master while rendering every localizable
/// word as a separate Flutter text layer. It does not redraw phones or artwork,
/// erase text from a flattened source, or call an image-generation service.
///
/// The host must first prepare a master with the replaceable text removed and
/// supply a layer for each visible localizable region, including screen labels
/// and enlarged foreground cards. A finished export is a raster image; this
/// widget, its master, layer geometry and string catalogue are the editable source.
class LayeredPromotionTemplate extends StatelessWidget {
  const LayeredPromotionTemplate({
    super.key,
    required this.artwork,
    required this.designSize,
    required this.layers,
    required this.strings,
    required this.typography,
    required this.locale,
    this.fontFamilyFallback,
    this.prepared,
    this.artworkOverlay,
  });

  final ImageProvider artwork;
  final Size designSize;
  final List<PromotionTextLayer> layers;
  final Map<String, String> strings;
  final TextStyle Function(FontWeight weight) typography;
  final List<String>? fontFamilyFallback;
  final Locale locale;

  /// Optional host-owned vector restoration, painted over the artwork and
  /// beneath editable text, in the template's design coordinate system.
  final Widget? artworkOverlay;

  /// Pre-rasterized glyph ink for OCR-derived ink rectangles. Prepare it after
  /// fonts load in a real asynchronous I/O hook, then dispose it after export.
  final PreparedLayeredPromotion? prepared;

  @override
  Widget build(BuildContext context) {
    _validate();
    if (prepared != null) {
      if (prepared!._disposed || prepared!.locale != locale) {
        throw StateError(
            'Prepared text is disposed or belongs to another locale.');
      }
      for (final layer in layers) {
        final ready = prepared!._layers[layer.id];
        if (ready == null ||
            ready.text != strings[layer.id] ||
            !identical(ready.layer, layer)) {
          throw StateError(
              'Prepared text is stale for ${layer.id}; prepare again.');
        }
      }
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox.fromSize(
          size: designSize,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: Image(image: artwork, fit: BoxFit.fill)),
              if (artworkOverlay != null)
                Positioned.fill(child: artworkOverlay!),
              for (final layer in layers) _positionedLayer(layer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedLayer(PromotionTextLayer layer) {
    final Widget panel;
    if (prepared != null) {
      final ready = prepared!._layers[layer.id]!;
      panel = _PreparedInkText(ready);
    } else {
      panel = _LayerText(
        layer: layer,
        text: strings[layer.id]!,
        typography: typography,
        fontFamilyFallback: fontFamilyFallback,
        locale: locale,
      );
    }
    if (layer.quad == null) {
      return Positioned.fromRect(rect: layer.rect, child: panel);
    }
    return Positioned(
      left: 0,
      top: 0,
      width: layer.rect.width,
      height: layer.rect.height,
      child: Transform(
        transform: promotionQuadTransform(layer.rect.size, layer.quad!),
        transformHitTests: false,
        child: panel,
      ),
    );
  }

  void _validate() {
    if (!_positiveFinite(designSize.width) ||
        !_positiveFinite(designSize.height)) {
      throw ArgumentError('Template designSize must be positive and finite.');
    }
    final ids = <String>{};
    for (final layer in layers) {
      if (layer.leadingIcon != null && prepared == null) {
        throw StateError(
            'Icon-and-label groups require prepared glyph ink: ${layer.id}.');
      }
      if (layer.id.isEmpty || !ids.add(layer.id)) {
        throw ArgumentError('Text layer IDs must be nonempty and unique.');
      }
      final value = strings[layer.id];
      if (value == null || value.trim().isEmpty) {
        throw StateError('Missing translated text for ${locale.toLanguageTag()}'
            '/${layer.id}.');
      }
      if (!layer.rect.left.isFinite ||
          !layer.rect.top.isFinite ||
          !_positiveFinite(layer.rect.width) ||
          !_positiveFinite(layer.rect.height) ||
          !_positiveFinite(layer.minFontSize) ||
          !_positiveFinite(layer.maxFontSize) ||
          layer.minFontSize > layer.maxFontSize ||
          !_positiveFinite(layer.lineHeight) ||
          !layer.letterSpacing.isFinite ||
          !_positiveFinite(layer.iconSize) ||
          !layer.iconGap.isFinite ||
          layer.iconGap < 0 ||
          layer.maxLines < 1) {
        throw ArgumentError('Invalid text geometry/style for ${layer.id}.');
      }
      if (layer.gradient != null && layer.gradient!.length < 2) {
        throw ArgumentError(
            'Provide at least two gradient colors: ${layer.id}');
      }
      if (layer.quad != null) {
        // Validate before any image is painted, with the layer ID as context.
        try {
          promotionQuadTransform(layer.rect.size, layer.quad!);
        } on ArgumentError catch (error) {
          throw ArgumentError('Invalid projection for ${layer.id}: $error');
        }
      }
    }
  }
}

class _LayerText extends StatelessWidget {
  const _LayerText({
    required this.layer,
    required this.text,
    required this.typography,
    required this.locale,
    this.fontFamilyFallback,
  });

  final PromotionTextLayer layer;
  final String text;
  final TextStyle Function(FontWeight weight) typography;
  final List<String>? fontFamilyFallback;
  final Locale locale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, bounds) {
          final direction = layer.direction ?? Directionality.of(context);
          final style = DefaultTextStyle.of(context)
              .style
              .merge(typography(layer.weight))
              .copyWith(
                color: layer.gradient == null ? layer.color : Colors.white,
                fontWeight: layer.weight,
                fontFamilyFallback: fontFamilyFallback,
                height: layer.lineHeight,
                letterSpacing: layer.letterSpacing,
              );
          final painter = TextPainter(
            textDirection: direction,
            locale: locale,
            textAlign: layer.alignment,
            maxLines: layer.maxLines,
            textScaler: TextScaler.noScaling,
          );
          var size = layer.maxFontSize;
          try {
            while (true) {
              painter.text = TextSpan(
                text: text,
                style: style.copyWith(fontSize: size),
              );
              painter.layout(maxWidth: bounds.maxWidth);
              final fits = !painter.didExceedMaxLines &&
                  painter.height <= bounds.maxHeight + .01 &&
                  (layer.maxLines != 1 ||
                      painter.maxIntrinsicWidth <= bounds.maxWidth + .01) &&
                  painter
                      .computeLineMetrics()
                      .every((line) => line.width <= bounds.maxWidth + .01);
              if (fits) break;
              if (size <= layer.minFontSize) {
                throw FlutterError('Text does not fit template layer '
                    '${locale.toLanguageTag()}/${layer.id}: "$text". '
                    'Panel ${bounds.maxWidth}×${bounds.maxHeight}, '
                    'minimum font ${layer.minFontSize}.');
              }
              size = math.max(layer.minFontSize, size - 1);
            }
          } finally {
            painter.dispose();
          }
          Widget result = RichText(
            text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
            maxLines: layer.maxLines,
            textAlign: layer.alignment,
            textDirection: direction,
            locale: locale,
            textScaler: TextScaler.noScaling,
          );
          if (layer.gradient != null) {
            result = ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: layer.gradient!,
              ).createShader(rect),
              child: result,
            );
          }
          return Align(
            alignment: Alignment(0, _verticalFactor(layer.verticalAlignment)),
            child: SizedBox(width: bounds.maxWidth, child: result),
          );
        },
      );
}

bool _positiveFinite(double value) => value.isFinite && value > 0;

double _verticalFactor(PromotionTextVerticalAlignment alignment) =>
    switch (alignment) {
      PromotionTextVerticalAlignment.top => -1,
      PromotionTextVerticalAlignment.center => 0,
      PromotionTextVerticalAlignment.bottom => 1,
    };

/// Project a local rectangle onto four absolute target corners in design pixels.
///
/// [corners] must be a finite convex quadrilateral ordered top-left, top-right,
/// bottom-right, bottom-left. The transformation is a true projective homography,
/// not a rotation or affine approximation, so text follows photographed planes.
/// Winding may be reversed deliberately by the host; locale/RTL does not alter it.
Matrix4 promotionQuadTransform(Size panel, List<Offset> corners) {
  if (!_positiveFinite(panel.width) ||
      !_positiveFinite(panel.height) ||
      corners.length != 4 ||
      corners.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
    throw ArgumentError('Provide a positive panel and four finite corners.');
  }
  double? winding;
  for (var i = 0; i < 4; i++) {
    final a = corners[(i + 1) % 4] - corners[i];
    final b = corners[(i + 2) % 4] - corners[(i + 1) % 4];
    final cross = a.dx * b.dy - a.dy * b.dx;
    if (cross.abs() < 1e-9 || (winding != null && cross * winding < 0)) {
      throw ArgumentError(
          'Target corners must form a nondegenerate convex quad.');
    }
    winding ??= cross;
  }
  final source = [
    Offset.zero,
    Offset(panel.width, 0),
    Offset(panel.width, panel.height),
    Offset(0, panel.height),
  ];
  final rows = <List<double>>[];
  for (var i = 0; i < 4; i++) {
    final x = source[i].dx;
    final y = source[i].dy;
    final u = corners[i].dx;
    final v = corners[i].dy;
    rows.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
    rows.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  // Eight unknowns with h22 fixed to 1; partial pivoting avoids the instability
  // of a closed-form division by an almost-parallel pair of photographed edges.
  for (var column = 0; column < 8; column++) {
    var pivot = column;
    for (var row = column + 1; row < 8; row++) {
      if (rows[row][column].abs() > rows[pivot][column].abs()) pivot = row;
    }
    if (rows[pivot][column].abs() < 1e-12) {
      throw ArgumentError('Cannot solve a singular target quadrilateral.');
    }
    final swap = rows[column];
    rows[column] = rows[pivot];
    rows[pivot] = swap;
    final divisor = rows[column][column];
    for (var j = column; j < 9; j++) {
      rows[column][j] /= divisor;
    }
    for (var row = 0; row < 8; row++) {
      if (row == column) continue;
      final factor = rows[row][column];
      for (var j = column; j < 9; j++) {
        rows[row][j] -= factor * rows[column][j];
      }
    }
  }
  final h = [for (final row in rows) row[8]];
  for (final point in source) {
    if (h[6] * point.dx + h[7] * point.dy + 1 <= 1e-9) {
      throw ArgumentError('Projection crosses the perspective plane.');
    }
  }
  return Matrix4.identity()
    ..setEntry(0, 0, h[0])
    ..setEntry(0, 1, h[1])
    ..setEntry(0, 3, h[2])
    ..setEntry(1, 0, h[3])
    ..setEntry(1, 1, h[4])
    ..setEntry(1, 3, h[5])
    ..setEntry(3, 0, h[6])
    ..setEntry(3, 1, h[7]);
}

/// Deterministic, locale-specific rendered glyphs. The string catalogue and
/// geometry remain the editable source; these temporary rasters are only a
/// rendering cache. The host owns disposal after its final capture frame.
class PreparedLayeredPromotion {
  PreparedLayeredPromotion._(this.locale, this._layers);
  final Locale locale;
  final Map<String, _PreparedInkLayer> _layers;
  bool _disposed = false;

  /// Effective design-pixel font sizes after proportional fitting into ink boxes.
  Map<String, double> get effectiveFontSizes => Map.unmodifiable({
        for (final layer in _layers.values)
          layer.layer.id: layer.fontSize * layer.scale,
      });

  /// Exact fitted alpha-ink rectangles in each panel's local design pixels,
  /// before quadrilateral projection. Useful for checking button padding and
  /// centering independently of whether text merely fits its maximum size.
  Map<String, Rect> get localInkBounds => Map.unmodifiable({
        for (final ready in _layers.values)
          ready.layer.id: _placedGroupBounds(ready, ready.layer.rect.size).text,
      });

  /// Actual fitted icon-ink bounds in panel-local design pixels before projection.
  Map<String, Rect> get localIconBounds => Map.unmodifiable({
        for (final ready in _layers.values)
          if (ready.icon != null)
            ready.layer.id:
                _placedGroupBounds(ready, ready.layer.rect.size).icon!,
      });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final layer in _layers.values) {
      layer.image.dispose();
      layer.icon?.image.dispose();
    }
  }
}

class _PreparedInkLayer {
  const _PreparedInkLayer({
    required this.layer,
    required this.text,
    required this.image,
    required this.ink,
    required this.scale,
    required this.fontSize,
    required this.direction,
    this.icon,
  });
  final PromotionTextLayer layer;
  final String text;
  final ui.Image image;
  final Rect ink;
  final double scale;
  final double fontSize;
  final TextDirection direction;
  final _PreparedIconInk? icon;
}

class _PreparedIconInk {
  const _PreparedIconInk(this.image, this.ink, this.flipHorizontal);
  final ui.Image image;
  final Rect ink;
  final bool flipHorizontal;

  Size fittedSize(double maxSide) {
    final scale = math.min(maxSide / ink.width, maxSide / ink.height);
    return Size(ink.width * scale, ink.height * scale);
  }
}

/// Shape text after fonts load, rasterize it once, and measure actual alpha ink
/// rather than treating an OCR glyph rectangle as a Flutter line-height box.
/// This avoids shrinking an original headline merely to accommodate invisible
/// ascent/descent padding. Glyph aspect ratios are preserved before projection.
///
/// Call from the host's real-async `prepare` hook, never begin this work in a
/// widget build/fake animation clock. Supply [direction] explicitly for RTL;
/// an individual layer can override it for LTR values on an RTL interface.
/// The exact layer instances and strings must be passed to the template widget.
Future<PreparedLayeredPromotion> prepareLayeredPromotionText({
  required List<PromotionTextLayer> layers,
  required Map<String, String> strings,
  required TextStyle Function(FontWeight weight) typography,
  required Locale locale,
  List<String>? fontFamilyFallback,
  TextDirection direction = TextDirection.ltr,
}) async {
  final prepared = <String, _PreparedInkLayer>{};
  try {
    for (final layer in layers) {
      final text = strings[layer.id];
      if (text == null ||
          text.trim().isEmpty ||
          prepared.containsKey(layer.id)) {
        throw ArgumentError(
            'Missing/empty/duplicate ink-layer text: ${layer.id}');
      }
      if (!_positiveFinite(layer.rect.width) ||
          !_positiveFinite(layer.rect.height) ||
          !_positiveFinite(layer.minFontSize) ||
          !_positiveFinite(layer.maxFontSize) ||
          layer.maxFontSize < layer.minFontSize ||
          !_positiveFinite(layer.iconSize) ||
          !layer.iconGap.isFinite ||
          layer.iconGap < 0 ||
          layer.maxLines < 1) {
        throw ArgumentError('Invalid ink layer: ${layer.id}');
      }
      final actualDirection = layer.direction ?? direction;
      final hasIcon = layer.leadingIcon != null;
      final style = typography(layer.weight).copyWith(
        color: layer.gradient == null ? layer.color : Colors.white,
        fontWeight: layer.weight,
        fontFamilyFallback: fontFamilyFallback,
        height: layer.lineHeight,
        letterSpacing: layer.letterSpacing,
        inherit: false,
      );
      final painter = TextPainter(
        textDirection: actualDirection,
        locale: locale,
        textAlign: layer.alignment,
        maxLines: layer.maxLines,
        textScaler: TextScaler.noScaling,
      );
      ui.Image? image;
      _PreparedIconInk? icon;
      var size = layer.maxFontSize;
      try {
        if (hasIcon) {
          icon = await _prepareIconInk(
              layer.leadingIcon!,
              layer.iconSize,
              actualDirection,
              layer.gradient == null ? layer.color : Colors.white);
        }
        final iconSize = icon?.fittedSize(layer.iconSize) ?? Size.zero;
        final textWidth =
            layer.rect.width - (hasIcon ? iconSize.width + layer.iconGap : 0);
        if (textWidth <= 0 || iconSize.height > layer.rect.height) {
          throw FlutterError(
              'Icon leaves no valid label area for ${layer.id}.');
        }
        while (true) {
          painter.text =
              TextSpan(text: text, style: style.copyWith(fontSize: size));
          // A one-line label is measured in full before proportional scaling.
          // Multi-line copy wraps at the panel width and must respect maxLines.
          painter.layout(
              maxWidth: layer.maxLines == 1 ? double.infinity : textWidth);
          if (!painter.didExceedMaxLines) break;
          if (size <= layer.minFontSize) {
            throw FlutterError('Too many lines in ${locale.toLanguageTag()}'
                '/${layer.id}: "$text"');
          }
          size = math.max(layer.minFontSize, size - 1);
        }
        final pad = math.max(8.0, size * .4).ceil();
        final width = painter.width.ceil() + pad * 2;
        final height = painter.height.ceil() + pad * 2;
        if (width < 1 ||
            height < 1 ||
            width > 8192 ||
            height > 8192 ||
            width * height > 16777216) {
          throw FlutterError('Ink raster is too large for ${layer.id}.');
        }
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, Offset(pad.toDouble(), pad.toDouble()));
        final picture = recorder.endRecording();
        try {
          image = await picture.toImage(width, height);
        } finally {
          picture.dispose();
        }
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (rgba == null) throw StateError('No glyph pixels for ${layer.id}.');
        final pixels =
            rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
        var left = width;
        var top = height;
        var right = -1;
        var bottom = -1;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            if (pixels[(y * width + x) * 4 + 3] == 0) continue;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
        if (right < left || bottom < top) {
          throw FlutterError('No visible glyph ink for ${layer.id}: "$text"');
        }
        final ink = Rect.fromLTRB(
            left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
        final scale = math.min(1.0,
            math.min(textWidth / ink.width, layer.rect.height / ink.height));
        if (size * scale < layer.minFontSize - .01) {
          throw FlutterError('Ink does not fit ${locale.toLanguageTag()}'
              '/${layer.id}: "$text". Effective font ${size * scale}, '
              'minimum ${layer.minFontSize}. Shorten copy or enlarge its panel.');
        }
        prepared[layer.id] = _PreparedInkLayer(
          layer: layer,
          text: text,
          image: image,
          ink: ink,
          scale: scale,
          fontSize: size,
          direction: actualDirection,
          icon: icon,
        );
        image = null; // Ownership moves to the prepared template.
        icon = null;
      } finally {
        painter.dispose();
        image?.dispose();
        icon?.image.dispose();
      }
    }
    return PreparedLayeredPromotion._(locale, Map.unmodifiable(prepared));
  } catch (_) {
    for (final layer in prepared.values) {
      layer.image.dispose();
      layer.icon?.image.dispose();
    }
    rethrow;
  }
}

class _PreparedInkText extends StatelessWidget {
  const _PreparedInkText(this.ready);
  final _PreparedInkLayer ready;

  @override
  Widget build(BuildContext context) {
    Widget result = CustomPaint(painter: _InkLayerPainter(ready));
    final colors = ready.layer.gradient;
    if (colors != null) {
      result = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
        child: result,
      );
    }
    return result;
  }
}

class _InkLayerPainter extends CustomPainter {
  const _InkLayerPainter(this.ready);
  final _PreparedInkLayer ready;

  @override
  void paint(Canvas canvas, Size size) {
    final placement = _placedGroupBounds(ready, size);
    canvas.drawImageRect(
        ready.image,
        ready.ink,
        placement.text,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true);
    final icon = ready.icon;
    final target = placement.icon;
    if (icon != null && target != null) {
      canvas.save();
      if (icon.flipHorizontal) {
        canvas.translate(target.center.dx * 2, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawImageRect(
          icon.image,
          icon.ink,
          target,
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_InkLayerPainter oldDelegate) =>
      !identical(oldDelegate.ready, ready);
}

({Rect text, Rect? icon}) _placedGroupBounds(
    _PreparedInkLayer ready, Size panel) {
  final width = ready.ink.width * ready.scale;
  final height = ready.ink.height * ready.scale;
  final hasIcon = ready.icon != null;
  final iconSize = ready.icon?.fittedSize(ready.layer.iconSize) ?? Size.zero;
  final gap = hasIcon ? ready.layer.iconGap : 0.0;
  final groupWidth = width + iconSize.width + gap;
  final groupHeight = math.max(height, iconSize.height);
  final available = math.max(0.0, panel.width - groupWidth);
  final double x;
  switch (ready.layer.alignment) {
    case TextAlign.center:
      x = available / 2;
    case TextAlign.left:
      x = 0;
    case TextAlign.right:
      x = available;
    case TextAlign.end:
      x = ready.direction == TextDirection.rtl ? 0 : available;
    case TextAlign.start:
    case TextAlign.justify:
      x = ready.direction == TextDirection.rtl ? available : 0;
  }
  final spareHeight = math.max(0.0, panel.height - groupHeight);
  final y =
      spareHeight * (_verticalFactor(ready.layer.verticalAlignment) + 1) / 2;
  final rtl = ready.direction == TextDirection.rtl;
  return (
    text: Rect.fromLTWH(x + (hasIcon && !rtl ? iconSize.width + gap : 0),
        y + (groupHeight - height) / 2, width, height),
    icon: !hasIcon
        ? null
        : Rect.fromLTWH(
            x + (rtl ? width + gap : 0),
            y + (groupHeight - iconSize.height) / 2,
            iconSize.width,
            iconSize.height),
  );
}

Future<_PreparedIconInk> _prepareIconInk(
    IconData icon, double size, TextDirection direction, Color color) async {
  final painter = TextPainter(
    text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
            inherit: false)),
    textDirection: TextDirection.ltr,
  )..layout();
  ui.Image? image;
  try {
    const pad = 8;
    final width = painter.width.ceil() + pad * 2;
    final height = painter.height.ceil() + pad * 2;
    if (width > 8192 || height > 8192 || width * height > 16777216) {
      throw ArgumentError('Icon raster exceeds supported dimensions.');
    }
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(8, 8));
    final picture = recorder.endRecording();
    try {
      image = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) throw StateError('No icon pixels.');
    final pixels =
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
    var left = width;
    var top = height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (pixels[(y * width + x) * 4 + 3] == 0) continue;
        left = math.min(left, x);
        top = math.min(top, y);
        right = math.max(right, x);
        bottom = math.max(bottom, y);
      }
    }
    if (right < left || bottom < top) {
      throw StateError('No visible icon glyph for ${icon.codePoint}.');
    }
    final result = _PreparedIconInk(
        image,
        Rect.fromLTRB(
            left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0),
        icon.matchTextDirection && direction == TextDirection.rtl);
    image = null;
    return result;
  } finally {
    painter.dispose();
    image?.dispose();
  }
}
