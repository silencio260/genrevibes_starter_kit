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
      _presentInDebug('platform', error, stack);
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
      _presentInDebug('zone', error, stack);
    });
  }

  /// Prints an uncaught error during development.
  ///
  /// Crash collection is normally disabled in debug builds so local runs do not
  /// pollute production crash-free rates. Without this, an error thrown while
  /// `main` is still awaiting startup work reaches the reporter, is dropped
  /// there, and leaves the application stopped at the launch screen with no
  /// output at all. Unlike `FlutterError.onError`, neither the zone handler nor
  /// `PlatformDispatcher.onError` has a framework default that presents it.
  static void _presentInDebug(String source, Object error, StackTrace? stack) {
    if (!kDebugMode) return;
    debugPrint('[genrevibes] uncaught $source error: $error');
    // Printed verbatim rather than through `debugPrintStack`, which parses
    // frames and asserts on `package:stack_trace` chained traces. A diagnostic
    // that throws while reporting a failure is worse than no diagnostic.
    if (stack != null) debugPrint(stack.toString());
  }
}
