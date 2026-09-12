import 'dart:async';

import 'package:flutter/widgets.dart';

import '../onboarding_controller.dart';

/// The work an [OnboardingAction] performs.
///
/// It receives the flow's [BuildContext], mounted when the action starts.
typedef OnboardingActionRun = FutureOr<void> Function(BuildContext context);

/// One step run when onboarding finishes or is skipped.
///
/// Actions run in order, each awaited, so "open the paywall, mark onboarding
/// complete, then go home" is three actions in a list, and an app that only
/// navigates passes one. A failing action stops the sequence unless
/// [continueOnError] is set; the flow reports the error and the user can try
/// again.
final class OnboardingAction {
  /// Creates an action that performs [run].
  const OnboardingAction(
    this.run, {
    this.name = 'custom',
    this.continueOnError = false,
    this.timeout,
  });

  /// Marks onboarding complete through [controller].
  ///
  /// Fails when the flag cannot be written, so a navigation after it never
  /// leaves a user onboarded in memory but not on disk.
  factory OnboardingAction.markCompleted(
    OnboardingController controller, {
    bool continueOnError = false,
  }) =>
      OnboardingAction(
        (_) async {
          final result = await controller.complete();
          final error = result.fold(
            onSuccess: (_) => null,
            onFailure: (value) => value,
          );
          if (error != null) throw OnboardingActionException(error.message);
        },
        name: 'mark_completed',
        continueOnError: continueOnError,
      );

  /// Opens [routeName], removing every route below it when [clearStack].
  ///
  /// Completes once the route is pushed, not when it is popped.
  factory OnboardingAction.navigate(
    String routeName, {
    Object? arguments,
    bool clearStack = true,
  }) =>
      OnboardingAction(
        (context) {
          final navigator = Navigator.of(context);
          if (clearStack) {
            unawaited(
              navigator.pushNamedAndRemoveUntil<void>(
                routeName,
                (_) => false,
                arguments: arguments,
              ),
            );
          } else {
            unawaited(navigator.pushNamed<void>(routeName, arguments: arguments));
          }
        },
        name: 'navigate:$routeName',
      );

  /// Runs [action] only when [condition] holds at the moment it would run.
  ///
  /// For a step that depends on state onboarding cannot see, such as showing
  /// the paywall only to a user who is not already premium.
  factory OnboardingAction.when(
    bool Function() condition,
    OnboardingAction action,
  ) =>
      OnboardingAction(
        (context) => condition() ? action.run(context) : null,
        name: 'when:${action.name}',
        continueOnError: action.continueOnError,
        timeout: action.timeout,
      );

  /// The work itself.
  final OnboardingActionRun run;

  /// A short name for logs and error reports.
  final String name;

  /// Whether the next action still runs when this one fails or times out.
  final bool continueOnError;

  /// How long this action may take before it counts as failed.
  final Duration? timeout;
}

/// Thrown by a built-in [OnboardingAction] that could not do its work.
final class OnboardingActionException implements Exception {
  /// Creates an exception with [message].
  const OnboardingActionException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'OnboardingActionException: $message';
}
