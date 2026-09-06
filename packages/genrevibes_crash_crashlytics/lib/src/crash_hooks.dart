import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genrevibes_crash/genrevibes_crash.dart';

/// Restores the framework handlers that [CrashHooks.install] replaced.
final class CrashHooksHandle {
  CrashHooksHandle._(this._restore);

  final void Function() _restore;

  /// Puts the previous handlers back.
  void restore() => _restore();
}

/// Routes framework and zone errors into a [CrashCoordinator].
///
/// Install once, from `main`, and let nothing else record errors on its own
/// path: a second wiring double-reports every crash.
abstract final class CrashHooks {
  /// Sets `FlutterError.onError` and `PlatformDispatcher.onError`.
  ///
  /// Previous handlers are chained so a debugger or test binding still sees
  /// the error. Returns a handle that restores them.
  static CrashHooksHandle install(CrashCoordinator coordinator) {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      previousFlutter?.call(details);
      unawaited(
        coordinator.report(
          CrashReport(
            error: details,
            stackTrace: details.stack,
            reason: details.context?.toDescription(),
            fatal: true,
            source: CrashSource.flutter,
          ),
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        coordinator.report(
          CrashReport(
            error: error,
            stackTrace: stack,
            fatal: true,
            source: CrashSource.platform,
          ),
        ),
      );
      return previousPlatform?.call(error, stack) ?? true;
    };

    return CrashHooksHandle._(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
    });
  }

  /// Runs [body] in a guarded zone that reports uncaught async errors.
  ///
  /// Wrap the whole of `main` in this so errors the framework hooks never see,
  /// such as a failed `Future` nobody awaited, still reach the reporter.
  static R? runGuarded<R>(R Function() body, CrashCoordinator coordinator) {
    return runZonedGuarded<R>(body, (error, stack) {
      unawaited(
        coordinator.report(
          CrashReport(
            error: error,
            stackTrace: stack,
            fatal: true,
            source: CrashSource.zone,
          ),
        ),
      );
    });
  }
}
