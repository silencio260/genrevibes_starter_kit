import 'dart:io';

import 'package:args/args.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:genrevibes_screenshot_tools/play_store.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('plan',
        help:
            'Source JSON containing explicit locale mappings, copy, and final image paths.')
    ..addFlag('remote-check',
        negatable: false,
        help: 'Upload into a temporary edit, validate, then discard it.')
    ..addFlag('apply',
        negatable: false, help: 'Upload and commit changes to Play Console.')
    ..addFlag('submit-for-review',
        negatable: false,
        help: 'Explicitly submit committed changes for review.')
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args['help'] as bool) {
      stdout.writeln(
          'Default: local checks only; no credentials or network required.\n${parser.usage}');
      return;
    }
    if (args['plan'] == null || args.rest.isNotEmpty) {
      throw FormatException(
          'Supply --plan path/to/upload-plan.json.\n${parser.usage}');
    }
    final apply = args['apply'] as bool;
    final remoteCheck = args['remote-check'] as bool;
    final review = args['submit-for-review'] as bool;
    if ((apply && remoteCheck) || (review && !apply)) {
      throw FormatException(
          'Choose --remote-check or --apply; review submission requires --apply.');
    }
    final plan = await PlayUploadPlan.read(File(args['plan'] as String));
    stdout.writeln('App: ${plan.packageName}');
    for (final listing in plan.listings) {
      stdout.writeln('${listing.appLocale} → ${listing.playLocale}: '
          '${listing.images.length} images, title and descriptions');
    }
    if (!apply && !remoteCheck) {
      stdout.writeln('Local checks passed. No Google Play changes made.');
      return;
    }
    final client = await clientViaApplicationDefaultCredentials(
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    );
    try {
      await PlayStoreUploader(client)
          .apply(plan, commit: apply, sendForReview: review);
    } finally {
      client.close();
    }
    stdout.writeln(remoteCheck
        ? 'Google Play validation passed; temporary edit discarded.'
        : review
            ? 'Changes committed and requested for review. Check Publishing overview for status.'
            : 'Changes committed without review submission. Check Publishing overview.');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
