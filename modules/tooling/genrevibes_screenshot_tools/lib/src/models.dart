import 'dart:async';

import 'package:flutter/widgets.dart';

/// A host-selected, ready translation. Store language mappings are separate.
class ScreenshotLocale {
  const ScreenshotLocale({
    required this.tag,
    required this.locale,
    this.directoryName,
  });

  final String tag;
  final Locale locale;

  /// Optional delivery folder, e.g. `US_English`. Defaults to [tag].
  /// This does not change locale matching, rendering or run-option filters.
  final String? directoryName;
}

class ScreenshotContext {
  const ScreenshotContext({required this.locale, required this.sceneId});

  final ScreenshotLocale locale;
  final String sceneId;
}

typedef ScreenshotBuilder = Widget Function(ScreenshotContext context);
typedef ScreenshotWrapper = Widget Function(
  ScreenshotContext context,
  Widget child,
);
typedef ScreenshotLifecycle = FutureOr<void> Function(
    ScreenshotContext context);

/// Physical pixels divided by pixelRatio give the widget's logical viewport.
class ScreenshotSize {
  const ScreenshotSize(this.width, this.height, {this.pixelRatio = 3});

  static const phone = ScreenshotSize(1080, 1920);
  static const featureGraphic = ScreenshotSize(1024, 500, pixelRatio: 2);

  final int width;
  final int height;
  final double pixelRatio;

  Size get logicalSize => Size(width / pixelRatio, height / pixelRatio);

  void validate() {
    if (width < 1 ||
        height < 1 ||
        width > 8192 ||
        height > 8192 ||
        !pixelRatio.isFinite ||
        pixelRatio <= 0) {
      throw ArgumentError(
          'Invalid screenshot size: $width x $height @ $pixelRatio');
    }
  }
}

/// The builder may return a real screen or a promotion containing a real screen.
/// Filenames are stable and ordered by the host, e.g. 01-start-mining.png.
class ScreenshotScene {
  const ScreenshotScene({
    required this.id,
    required this.filename,
    required this.builder,
    this.size = ScreenshotSize.phone,
    this.prepare,
    this.dispose,
    this.frames = 4,
    this.frameDuration = const Duration(milliseconds: 100),
  });

  final String id;
  final String filename;
  final ScreenshotBuilder builder;
  final ScreenshotSize size;
  final ScreenshotLifecycle? prepare;
  final ScreenshotLifecycle? dispose;

  /// Bounded frames avoid waiting forever on countdowns and looping animations.
  final int frames;
  final Duration frameDuration;
}

class ScreenshotProject {
  const ScreenshotProject({
    required this.campaign,
    required this.locales,
    required this.scenes,
    required this.wrap,
    this.outputDirectory = 'app_screenshots',
    this.requireIgnoredOutput = true,
    this.prepare,
    this.dispose,
  });

  final String campaign;
  final List<ScreenshotLocale> locales;
  final List<ScreenshotScene> scenes;

  /// Supplies app delegates, theme, directionality, fonts and state providers.
  /// Native application bootstrap is deliberately not invoked by the kit.
  final ScreenshotWrapper wrap;
  final String outputDirectory;
  final bool requireIgnoredOutput;
  final ScreenshotLifecycle? prepare;
  final ScreenshotLifecycle? dispose;
}

/// Pass --dart-define=SCREENSHOT_LOCALES=en-US,fr-FR to select a batch.
class ScreenshotRunOptions {
  const ScreenshotRunOptions({
    this.locales = const {},
    this.scenes = const {},
    this.replace = false,
  });

  factory ScreenshotRunOptions.fromEnvironment() {
    Set<String> split(String value) => value
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return ScreenshotRunOptions(
      locales: split(const String.fromEnvironment('SCREENSHOT_LOCALES')),
      scenes: split(const String.fromEnvironment('SCREENSHOT_SCENES')),
      replace: const bool.fromEnvironment('SCREENSHOT_REPLACE'),
    );
  }

  final Set<String> locales;
  final Set<String> scenes;
  final bool replace;
}
