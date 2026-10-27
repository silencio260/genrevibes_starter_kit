import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as raster;
import 'package:path/path.dart' as p;

import 'models.dart';

/// Registers an export job with Flutter's headless runner, not golden baselines.
/// Host entrypoints live in tool/, not the app runtime or a generated test tree.
/// Run explicitly with `flutter test tool/<entry>.dart` after local authorization.
void registerScreenshotExports(
  ScreenshotProject project, {
  ScreenshotRunOptions? options,
}) {
  final selected = options ?? ScreenshotRunOptions.fromEnvironment();
  _validateProject(project, selected);
  final locales = project.locales
      .where(
        (locale) =>
            selected.locales.isEmpty || selected.locales.contains(locale.tag),
      )
      .toList();
  final scenes = project.scenes
      .where(
        (scene) =>
            selected.scenes.isEmpty || selected.scenes.contains(scene.id),
      )
      .toList();

  testWidgets('Export ${project.campaign}', (tester) async {
    final paths = [
      for (final locale in locales)
        for (final scene in scenes)
          p.join(project.campaign, locale.directoryName ?? locale.tag,
              scene.filename),
    ];
    final root = p.normalize(p.absolute(project.outputDirectory));
    await _realAsync(tester, () => _preflight(root, paths, project, selected));
    final staging = await _realAsync(
      tester,
      () => Directory.systemTemp.createTemp('genrevibes-screenshots-'),
    );
    if (staging == null) {
      throw StateError('Cannot create screenshot staging directory.');
    }
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _realAsync(tester, loadBundledScreenshotFonts);
      for (final locale in locales) {
        for (final scene in scenes) {
          final context = ScreenshotContext(locale: locale, sceneId: scene.id);
          final boundaryKey = GlobalKey();
          var projectPrepared = false;
          var scenePrepared = false;
          Object? sceneFailure;
          try {
            projectPrepared = true;
            await _realAsync(
                tester, () async => project.prepare?.call(context));
            scenePrepared = true;
            await _realAsync(tester, () async => scene.prepare?.call(context));
            tester.view.devicePixelRatio = scene.size.pixelRatio;
            tester.view.physicalSize = Size(
              scene.size.width.toDouble(),
              scene.size.height.toDouble(),
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: project.wrap(
                    context,
                    Builder(
                      builder: (_) => scene.builder(context),
                    )),
              ),
            );
            for (var frame = 0; frame < scene.frames; frame++) {
              await tester.pump(scene.frameDuration);
              _throwRenderingException(tester, context);
              await _precacheVisibleImages(tester);
            }
            await tester.pump();
            _throwRenderingException(tester, context);
            final boundary = boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            await _realAsync(tester, () async {
              final image =
                  await boundary.toImage(pixelRatio: scene.size.pixelRatio);
              try {
                final rgba =
                    await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                if (rgba == null) {
                  throw StateError('No pixel data for ${scene.id}.');
                }
                final file = File(p.join(staging.path, project.campaign,
                    locale.directoryName ?? locale.tag, scene.filename));
                final pixels = raster.Image.fromBytes(
                  width: image.width,
                  height: image.height,
                  bytes: rgba.buffer,
                  bytesOffset: rgba.offsetInBytes,
                  numChannels: 4,
                );
                // Flatten transparency to white, then encode a true RGB PNG.
                final opaque = raster.Image(
                  width: image.width,
                  height: image.height,
                  numChannels: 3,
                );
                raster.fill(opaque, color: raster.ColorRgb8(255, 255, 255));
                raster.compositeImage(opaque, pixels);
                await file.parent.create(recursive: true);
                await file.writeAsBytes(raster.encodePng(opaque), flush: true);
                if (opaque.width != scene.size.width ||
                    opaque.height != scene.size.height) {
                  throw StateError(
                      'Unexpected export dimensions: ${scene.filename}');
                }
              } finally {
                image.dispose();
              }
            });
          } catch (error) {
            sceneFailure = error;
            rethrow;
          } finally {
            try {
              // Disposing the tree cancels timers before the next locale.
              await tester.pumpWidget(const SizedBox.shrink());
              try {
                if (scenePrepared) {
                  await _realAsync(
                      tester, () async => scene.dispose?.call(context));
                }
              } finally {
                if (projectPrepared) {
                  await _realAsync(
                      tester, () async => project.dispose?.call(context));
                }
              }
            } catch (cleanupError) {
              if (sceneFailure == null) rethrow;
              debugPrint('Screenshot cleanup also failed: $cleanupError');
            }
          }
          _throwRenderingException(tester, context);
        }
      }
      // All requested images must render successfully before publishing any.
      await _realAsync(tester, () async {
        await _preflight(root, paths, project, selected);
        for (final relative in paths) {
          final destination = File(p.join(root, relative));
          await destination.parent.create(recursive: true);
          final temporary = File('${destination.path}.rendering');
          try {
            await File(p.join(staging.path, relative)).copy(temporary.path);
            await temporary.rename(destination.path);
          } finally {
            if (await temporary.exists()) await temporary.delete();
          }
        }
      });
      debugPrint(
          'Exported ${paths.length} final images to $root/${project.campaign}.');
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await _realAsync(tester, () => staging.delete(recursive: true));
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// Avoid the test runner's square-glyph font, including for Material icons.
/// The host must additionally prepare fonts fetched by font-provider packages.
Future<void> loadBundledScreenshotFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void _throwRenderingException(WidgetTester tester, ScreenshotContext context) {
  final exception = tester.takeException();
  if (exception != null) {
    throw FlutterError(
        'Failed to render ${context.locale.tag}/${context.sceneId}: $exception');
  }
}

Future<void> _precacheVisibleImages(WidgetTester tester) async {
  final elements = tester.elementList(find.byType(Image)).toList();
  await _realAsync(tester, () async {
    for (final element in elements) {
      Object? failure;
      await precacheImage((element.widget as Image).image, element,
              onError: (error, _) => failure = error)
          .timeout(const Duration(seconds: 45));
      if (failure != null) {
        throw StateError('Screenshot image did not load: $failure');
      }
    }
  });
}

/// WidgetTester.runAsync normally records failures and returns null. Propagate
/// lifecycle/I/O failures immediately so the next stage cannot use partial state.
Future<T?> _realAsync<T>(
    WidgetTester tester, Future<T> Function() callback) async {
  Object? failure;
  StackTrace? failureStack;
  final result = await tester.runAsync<T?>(() async {
    try {
      return await callback();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
      return null;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return result;
}

void _validateProject(ScreenshotProject project, ScreenshotRunOptions options) {
  final component = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');
  void check(String value) {
    if (!component.hasMatch(value)) {
      throw ArgumentError('Unsafe output component: $value');
    }
  }

  check(project.campaign);
  if (project.locales.isEmpty || project.scenes.isEmpty) {
    throw ArgumentError('Provide ready locales and screenshot scenes.');
  }
  final tags = <String>{};
  final directoryNames = <String>{};
  final ids = <String>{};
  final filenames = <String>{};
  for (final locale in project.locales) {
    check(locale.tag);
    final directoryName = locale.directoryName ?? locale.tag;
    check(directoryName);
    if (!directoryNames.add(directoryName.toLowerCase())) {
      throw ArgumentError('Duplicate locale output folder: $directoryName');
    }
    if (!tags.add(locale.tag)) {
      throw ArgumentError('Duplicate locale: ${locale.tag}');
    }
    if (locale.locale.toLanguageTag() != locale.tag) {
      throw ArgumentError(
          'Locale tag and Flutter locale differ: ${locale.tag}');
    }
  }
  for (final scene in project.scenes) {
    check(scene.id);
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*\.png$').hasMatch(scene.filename)) {
      throw ArgumentError('Use a simple PNG filename: ${scene.filename}');
    }
    if (!ids.add(scene.id) || !filenames.add(scene.filename.toLowerCase())) {
      throw ArgumentError('Duplicate scene ID or output filename: ${scene.id}');
    }
    scene.size.validate();
    if (scene.frames < 1 || scene.frameDuration.isNegative) {
      throw ArgumentError('Use bounded positive rendering frames.');
    }
  }
  if (options.locales.difference(tags).isNotEmpty ||
      options.scenes.difference(ids).isNotEmpty) {
    throw ArgumentError('Requested unknown/unready locale or scene. '
        'Locales: ${tags.join(", ")}; scenes: ${ids.join(", ")}.');
  }
}

Future<void> _preflight(String root, List<String> paths,
    ScreenshotProject project, ScreenshotRunOptions options) async {
  if (root == p.current || p.equals(root, Directory.current.path)) {
    throw ArgumentError('Use a dedicated screenshot output directory.');
  }
  if (project.requireIgnoredOutput) {
    final ignored = await Process.run(
        'git', ['check-ignore', '--quiet', '--no-index', '$root/']);
    final tracked = await Process.run('git', ['ls-files', '-z', '--', root]);
    if (ignored.exitCode != 0 ||
        tracked.exitCode != 0 ||
        (tracked.stdout as String).isNotEmpty) {
      throw StateError(
          'The entire output directory must be Git-ignored and untracked: $root');
    }
  }
  for (final relative in paths) {
    final destination = p.join(root, relative);
    for (var current = destination;; current = p.dirname(current)) {
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('Refusing a symlink in the output path: $current');
      }
      if (p.equals(current, root) || current == p.dirname(current)) break;
    }
    final type = await FileSystemEntity.type(destination, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        (type != FileSystemEntityType.file || !options.replace)) {
      throw StateError(
          'Output exists: $destination. Use SCREENSHOT_REPLACE=true to replace final images.');
    }
    if (await FileSystemEntity.type('$destination.rendering',
            followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Temporary output collision: $destination.rendering');
    }
  }
}
