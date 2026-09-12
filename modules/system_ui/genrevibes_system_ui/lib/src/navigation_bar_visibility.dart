import 'package:flutter/widgets.dart';

import 'navigation_bar_controller.dart';
import 'navigation_bar_scope.dart';

/// Shows or hides the navigation bar while this screen is on top.
///
/// Wrap the screen, typically its `Scaffold`:
///
/// ```dart
/// NavigationBarVisibility(visible: true, child: Scaffold(...))
/// ```
///
/// The request belongs to the route the widget is in. It applies while that
/// route is on top, including under a dialog or sheet opened from it, and ends
/// when the route goes. Developer access with the developer switch on still
/// shows the bar on every screen.
///
/// Without a `NavigationBarScope` above it, this does nothing.
class NavigationBarVisibility extends StatefulWidget {
  /// Creates the request.
  const NavigationBarVisibility({
    required this.visible,
    required this.child,
    super.key,
  });

  /// Whether the navigation bar shows on this screen.
  final bool visible;

  /// The screen.
  final Widget child;

  @override
  State<NavigationBarVisibility> createState() =>
      _NavigationBarVisibilityState();
}

class _NavigationBarVisibilityState extends State<NavigationBarVisibility> {
  NavigationBarController? _controller;
  NavigationBarRequest? _request;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = NavigationBarScope.maybeOf(context);
    final route = ModalRoute.of(context);
    final request = _request;
    if (request != null &&
        identical(controller, _controller) &&
        identical(route, request.route)) {
      return;
    }
    request?.release();
    _controller = controller;
    _request = controller == null || route == null
        ? null
        : controller.request(route, visible: widget.visible);
  }

  @override
  void didUpdateWidget(NavigationBarVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    _request?.visible = widget.visible;
  }

  @override
  void dispose() {
    _request?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
