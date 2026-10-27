import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as raster;
import 'package:path/path.dart' as p;

class PlayImage {
  const PlayImage(
      {required this.path, required this.type, required this.bytes});
  final String path;
  final String type;
  final Uint8List bytes;
}

class PlayListingUpload {
  const PlayListingUpload({
    required this.appLocale,
    required this.playLocale,
    required this.copy,
    required this.images,
  });
  final String appLocale;
  final String playLocale;
  final Map<String, String> copy;
  final List<PlayImage> images;
}

/// Source configuration stays outside final image folders. Every mapping is
/// explicit: app locale tags are not assumed to be valid Play language slots.
class PlayUploadPlan {
  const PlayUploadPlan({required this.packageName, required this.listings});
  final String packageName;
  final List<PlayListingUpload> listings;

  static Future<PlayUploadPlan> read(File configuration) async {
    final source =
        jsonDecode(await configuration.readAsString()) as Map<String, dynamic>;
    final package = source['packageName'] as String;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')
        .hasMatch(package)) {
      throw FormatException('Invalid Android package name.');
    }
    final entries = source['listings'] as List;
    if (entries.isEmpty) throw FormatException('Provide at least one listing.');
    final languages = <String>{};
    final listings = <PlayListingUpload>[];
    for (final entry in entries.cast<Map<String, dynamic>>()) {
      final appLocale = entry['appLocale'] as String;
      final language = entry['playLocale'] as String;
      if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$').hasMatch(language) ||
          !languages.add(language)) {
        throw FormatException('Invalid or duplicate Play locale: $language');
      }
      final rawCopy = entry['copyFile'] != null
          ? jsonDecode(await File(p.normalize(p.join(
                  configuration.parent.path, entry['copyFile'] as String)))
              .readAsString()) as Map<String, dynamic>
          : entry['copy'] as Map<String, dynamic>;
      final copy = <String, String>{'language': language};
      for (final field in {
        'title': 30,
        'shortDescription': 80,
        'fullDescription': 4000
      }.entries) {
        final value = rawCopy[field.key] as String;
        if (value.trim().isEmpty || value.runes.length > field.value) {
          throw FormatException(
              '$language ${field.key} must contain 1–${field.value} characters.');
        }
        copy[field.key] = value;
      }
      final directory = p.normalize(
          p.join(configuration.parent.path, entry['directory'] as String));
      final names = (entry['screenshots'] as List).cast<String>();
      if (names.length < 2 ||
          names.length > 8 ||
          names.toSet().length != names.length) {
        throw FormatException(
            '$language needs 2–8 distinct phone screenshot filenames in upload order.');
      }
      final images = <PlayImage>[];
      for (final name in names) {
        images.add(await _readImage(directory, name, 'phoneScreenshots'));
      }
      if (entry['featureGraphic'] case final String name) {
        images.add(await _readImage(directory, name, 'featureGraphic'));
      }
      listings.add(PlayListingUpload(
        appLocale: appLocale,
        playLocale: language,
        copy: Map.unmodifiable(copy),
        images: List.unmodifiable(images),
      ));
    }
    return PlayUploadPlan(
        packageName: package, listings: List.unmodifiable(listings));
  }

  static Future<PlayImage> _readImage(
      String directory, String name, String type) async {
    if (p.basename(name) != name || !name.toLowerCase().endsWith('.png')) {
      throw FormatException(
          'Use a PNG filename directly inside the locale folder: $name');
    }
    final path = p.join(directory, name);
    final bytes = await File(path).readAsBytes();
    final decoded = raster.decodePng(bytes);
    if (decoded == null) throw FormatException('Invalid PNG: $path');
    if (type == 'featureGraphic') {
      if (decoded.width != 1024 || decoded.height != 500) {
        throw FormatException('Feature graphic must be 1024 × 500: $path');
      }
    } else {
      final short =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final long =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      if (short < 320 || long > 3840 || long > short * 2) {
        throw FormatException('Invalid phone screenshot dimensions: $path');
      }
    }
    if (decoded.hasAlpha) {
      throw FormatException('Use opaque RGB PNG exports: $path');
    }
    return PlayImage(path: path, type: type, bytes: bytes);
  }
}

/// The caller owns the authenticated client and its app-scoped Play permissions.
/// Each run owns one edit. No automatic retry can duplicate an uncertain commit.
class PlayStoreUploader {
  PlayStoreUploader(this.client, {this.timeout = const Duration(seconds: 60)});
  final http.Client client;
  final Duration timeout;

  /// Both modes upload into an edit and validate it. A remote check deletes the
  /// edit. Applying commits it; submission for review is a separate explicit flag.
  Future<void> apply(
    PlayUploadPlan plan, {
    required bool commit,
    bool sendForReview = false,
  }) async {
    if (sendForReview && !commit) {
      throw ArgumentError('Review submission requires commit.');
    }
    final base =
        'androidpublisher/v3/applications/${Uri.encodeComponent(plan.packageName)}/edits';
    final created = await _json('POST', base, body: const {});
    final id = created['id'] as String;
    final edit = '$base/${Uri.encodeComponent(id)}';
    var committed = false;
    var committing = false;
    try {
      for (final listing in plan.listings) {
        final language = Uri.encodeComponent(listing.playLocale);
        await _json('PUT', '$edit/listings/$language', body: listing.copy);
        for (final type in listing.images.map((image) => image.type).toSet()) {
          await _json('DELETE', '$edit/listings/$language/$type');
        }
        for (final image in listing.images) {
          await _json('POST', 'upload/$edit/listings/$language/${image.type}',
              query: const {'uploadType': 'media'}, bytes: image.bytes);
        }
      }
      await _json('POST', '$edit:validate');
      if (commit) {
        committing = true;
        await _json('POST', '$edit:commit', query: {
          'changesNotSentForReview': (!sendForReview).toString(),
        });
        committed = true;
      }
    } catch (error) {
      if (committing) {
        throw StateError(
            'Play commit did not return success. Verify Publishing overview '
            'before retrying; the outcome may be uncertain. $error');
      }
      rethrow;
    } finally {
      if (!committed) {
        try {
          await _json('DELETE', edit);
        } catch (_) {
          // An invalidated, committed or expired edit may no longer exist.
        }
      }
    }
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Uint8List? bytes,
  }) async {
    final uri = Uri.https('androidpublisher.googleapis.com', '/$path', query);
    final request = http.Request(method, uri);
    if (bytes != null) {
      request.headers['content-type'] = 'image/png';
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
            await client.send(request).timeout(timeout))
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        message = (error['error'] as Map<String, dynamic>)['message'] as String;
      } catch (_) {
        // Never print headers, credentials or an unstructured response body.
      }
      throw HttpException('Google Play ${response.statusCode}: $message');
    }
    return response.body.isEmpty
        ? {}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }
}
