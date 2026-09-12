import 'package:flutter/widgets.dart';

import 'navigation_bar_controller.dart';

/// Makes a [NavigationBarController] available to the screens below it.
///
/// Put it above `MaterialApp`, and add [NavigationBarController.observer] to
/// the app's `navigatorObservers`.
class NavigationBarScope extends InheritedWidget {
  /// Creates a scope.
  const NavigationBarScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The app's controller.
  final NavigationBarController controller;

  /// The nearest controller, or null when there is no scope.
  static NavigationBarController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NavigationBarScope>()
      ?.controller;

  @override
  bool updateShouldNotify(NavigationBarScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}
