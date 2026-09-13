import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'navigation_bar_keys.dart';
import 'system_navigation_bar.dart';

/// Why the navigation bar is shown or hidden.
enum NavigationBarReason {
  /// Developer access is granted and the developer switch is on.
  developer,

  /// The screen on top asked, through `NavigationBarVisibility`.
  screen,

  /// The route on top is named in [NavigationBarController.routes].
  route,

  /// Nothing asked, so [NavigationBarController.visibleByDefault] applies.
  byDefault,
}

/// Whether the navigation bar is shown, and why.
@immutable
final class NavigationBarState {
  /// Creates a state.
  const NavigationBarState({
    required this.visible,
    required this.reason,
    this.routeName,
  });

  /// Whether the navigation bar is shown.
  final bool visible;

  /// Why.
  final NavigationBarReason reason;

  /// The name of the route that decided it, or of the route on top when the
  /// developer switch did, when it has one.
  final String? routeName;

  @override
  bool operator ==(Object other) =>
      other is NavigationBarState &&
      other.visible == visible &&
      other.reason == reason &&
      other.routeName == routeName;

  @override
  int get hashCode => Object.hash(visible, reason, routeName);
}

/// One screen's request, held by whatever made it.
final class NavigationBarRequest {
  NavigationBarRequest._(this._controller, this.route, this._visible);

  final NavigationBarController _controller;
  bool _visible;
  bool _released = false;

  /// The route the request belongs to.
  final Route<dynamic> route;

  /// Whether the request is to show the navigation bar.
  bool get visible => _visible;

  set visible(bool value) {
    if (_released || value == _visible) return;
    _visible = value;
    _controller._scheduleApply();
  }

  /// Withdraws the request. Safe to call more than once.
  void release() {
    if (_released) return;
    _released = true;
    _controller._release(this);
  }
}

/// Decides whether the phone's system navigation bar is shown, screen by
/// screen, and applies it.
///
/// For everyone, the bar follows the screen on top: a screen that asked, then
/// the route names in [routes], then [visibleByDefault]. Dialogs, bottom sheets
/// and menus keep the bar of the screen under them unless they ask themselves.
///
/// With developer access granted — bound through [setDeveloperMode] — the bar
/// shows on every screen while the developer switch is on. The switch is
/// remembered on the device, and a developer turns it off to see screens the
/// way users do.
///
/// Activities opened over the app, above all full-screen ads, are shown full
/// screen: no status bar, and no navigation bar unless the developer switch
/// shows it on every screen. Pass `fullScreenOverlays: false` to leave them
/// alone.
///
/// Add [observer] to the root navigator and put a `NavigationBarScope` above
/// the app, so screens can ask with `NavigationBarVisibility`.
final class NavigationBarController implements StarterModule {
  /// Creates a controller.
  ///
  /// Without a [store] the developer switch is not remembered across launches.
  NavigationBarController({
    KeyValueStore? store,
    SystemNavigationBar navigationBar = const PlatformSystemNavigationBar(),
    bool visibleByDefault = false,
    Map<String, bool> routes = const <String, bool>{},
    bool developerShowsEverywhereByDefault = true,
    bool fullScreenOverlays = true,
    List<String> overlayExclusions = defaultOverlayExclusions,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _navigationBar = navigationBar,
        _visibleByDefault = visibleByDefault,
        _routes = Map<String, bool>.unmodifiable(routes),
        _developerShowsEverywhere = developerShowsEverywhereByDefault,
        _fullScreenOverlays = fullScreenOverlays,
        _overlayExclusions = List<String>.unmodifiable(overlayExclusions),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: _moduleId,
          state: ModuleState.idle,
          observedAt: clock.now(),
        ),
        _current = NavigationBarState(
          visible: visibleByDefault,
          reason: NavigationBarReason.byDefault,
        );

  static const _moduleId = 'system_ui.navigation_bar';

  /// Activities left as they are while activities over the app are shown full
  /// screen, by class name prefix: Flutter's own, purchases and subscriptions,
  /// sign-in, Google Play prompts and notification trampolines. None of them
  /// is a full-screen ad, and without a status bar they would look broken.
  static const List<String> defaultOverlayExclusions = <String>[
    'io.flutter.',
    'com.android.billingclient.',
    'com.revenuecat.',
    'com.google.android.play.core.',
    'com.google.android.gms.auth.',
    'com.google.android.gms.common.api.',
    'com.google.android.libraries.identity.',
    'androidx.credentials.',
    'com.onesignal.',
  ];

  final KeyValueStore? _store;
  final SystemNavigationBar _navigationBar;
  final bool _visibleByDefault;
  final Map<String, bool> _routes;
  final bool _fullScreenOverlays;
  final List<String> _overlayExclusions;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<NavigationBarState> _changes =
      StreamController<NavigationBarState>.broadcast();
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];
  final Map<Route<dynamic>, List<NavigationBarRequest>> _requests =
      <Route<dynamic>, List<NavigationBarRequest>>{};
  late final NavigatorObserver _observer = _NavigationBarObserver(this);
  ModuleHealth _health;
  NavigationBarState _current;
  bool _developerShowsEverywhere;
  bool _developerMode = false;
  bool? _applied;
  bool? _appliedOverlayNavigationBar;
  bool _applyScheduled = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => _moduleId;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Whether the bar is shown now, and why.
  NavigationBarState get current => _current;

  /// Emits each changed state.
  Stream<NavigationBarState> get changes => _changes.stream;

  /// Whether the bar shows on a screen that did not ask.
  bool get visibleByDefault => _visibleByDefault;

  /// Route names that show (`true`) or hide (`false`) the bar without asking
  /// from the screen.
  Map<String, bool> get routes => _routes;

  /// Whether developer access is granted.
  bool get developerMode => _developerMode;

  /// The developer switch: whether the bar shows on every screen while
  /// developer access is granted.
  bool get developerShowsEverywhere => _developerShowsEverywhere;

  /// Whether activities opened over the app, such as full-screen ads, are
  /// shown full screen.
  bool get fullScreenOverlays => _fullScreenOverlays;

  /// Class name prefixes of the activities [fullScreenOverlays] leaves alone.
  List<String> get overlayExclusions => _overlayExclusions;

  /// Whether the navigation bar shows over a full-screen ad: only while
  /// developer access is granted and the developer switch is on.
  bool get overlayNavigationBarVisible =>
      _developerMode && _developerShowsEverywhere;

  /// Whether this platform lets the app hide the navigation bar.
  bool get isSupported => _navigationBar.isSupported;

  /// Add to the root navigator's observers. It tells the controller which
  /// screen is on top.
  NavigatorObserver get observer => _observer;

  /// Reads the developer switch. The bar is applied once the navigator reports
  /// its first route.
  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady();
    if (_initialized) return const KitSuccess<void>(null);

    final store = _store;
    if (store != null) {
      final stored =
          await store.getBool(NavigationBarKeys.developerShowsEverywhere);
      if (stored.isFailure) {
        _logger.log(
          KitLogLevel.warning,
          'The developer navigation bar switch could not be read. '
          'Using the default.',
          moduleId: moduleId,
          error: stored.fold(onSuccess: (_) => null, onFailure: (e) => e),
        );
      } else {
        final value = stored.fold(onSuccess: (v) => v, onFailure: (_) => null);
        if (value != null) _developerShowsEverywhere = value;
      }
    }

    _initialized = true;
    _setHealth(ModuleState.ready);
    _scheduleApply();
    unawaited(_applyOverlays());
    return const KitSuccess<void>(null);
  }

  /// Whether developer access is granted. Bind it to the app's developer
  /// access decision, and call it again whenever that changes.
  void setDeveloperMode(bool granted) {
    if (_disposed || granted == _developerMode) return;
    _developerMode = granted;
    _scheduleApply();
    unawaited(_applyOverlays());
  }

  /// Sets the developer switch and remembers it on this device.
  Future<KitResult<void>> setDeveloperShowsEverywhere(bool value) async {
    if (!_initialized || _disposed) return _notReady();
    _developerShowsEverywhere = value;
    _scheduleApply();
    unawaited(_applyOverlays());
    final store = _store;
    if (store == null) return const KitSuccess<void>(null);
    return store.setBool(NavigationBarKeys.developerShowsEverywhere, value);
  }

  /// Asks for the bar to be [visible] while [route] is on top.
  ///
  /// `NavigationBarVisibility` calls this for a screen. Release the request
  /// when the route no longer wants it; the latest request on a route wins.
  NavigationBarRequest request(Route<dynamic> route, {required bool visible}) {
    final request = NavigationBarRequest._(this, route, visible);
    (_requests[route] ??= <NavigationBarRequest>[]).add(request);
    _scheduleApply();
    return request;
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _stack.clear();
    _requests.clear();
    _setHealth(ModuleState.disposed);
    await _changes.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _release(NavigationBarRequest request) {
    final requests = _requests[request.route];
    if (requests == null) return;
    requests.remove(request);
    if (requests.isEmpty) _requests.remove(request.route);
    _scheduleApply();
  }

  void _pushed(Route<dynamic> route) {
    _stack.add(route);
    _scheduleApply();
  }

  void _removed(Route<dynamic> route) {
    _stack.remove(route);
    _scheduleApply();
  }

  void _replaced(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute == null) {
      if (index >= 0) _stack.removeAt(index);
    } else if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
    _scheduleApply();
  }

  /// Decides after the frame in progress, or the next one.
  ///
  /// A route that was just pushed has not built its screen yet, and the
  /// screen's request arrives during that build. Deciding at once would hide
  /// the bar and show it again a frame later.
  ///
  /// Nothing is decided before the navigator reports its first route: until
  /// then there is no screen, and no frame to wait for.
  void _scheduleApply() {
    if (!_initialized || _disposed || _applyScheduled || _stack.isEmpty) {
      return;
    }
    _applyScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _applyScheduled = false;
        unawaited(_apply());
      })
      ..scheduleFrame();
  }

  Future<void> _apply() async {
    if (_disposed) return;
    final next = _resolve();
    if (next != _current) {
      _current = next;
      if (!_changes.isClosed) _changes.add(next);
      _setHealth(ModuleState.ready);
    }
    if (_applied == next.visible || !_navigationBar.isSupported) return;
    _applied = next.visible;
    try {
      await _navigationBar.setVisible(next.visible);
    } on Object catch (error, stackTrace) {
      _applied = null;
      final message = next.visible
          ? 'The navigation bar could not be shown.'
          : 'The navigation bar could not be hidden.';
      _logger.log(
        KitLogLevel.warning,
        message,
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      _setHealth(
        ModuleState.degraded,
        error: KitError(
          code: KitErrorCode.provider,
          message: message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Tells the platform how to show activities opened over the app.
  ///
  /// Unlike the app's own screens this waits for no frame or route: a splash
  /// ad can open before the first screen has settled.
  Future<void> _applyOverlays() async {
    if (!_initialized ||
        _disposed ||
        !_fullScreenOverlays ||
        !_navigationBar.isSupported) {
      return;
    }
    final visible = overlayNavigationBarVisible;
    if (_appliedOverlayNavigationBar == visible) return;
    _appliedOverlayNavigationBar = visible;
    try {
      await _navigationBar.setFullScreenOverlays(
        navigationBarVisible: visible,
        excludedActivityPrefixes: _overlayExclusions,
      );
    } on Object catch (error, stackTrace) {
      _appliedOverlayNavigationBar = null;
      const message = 'Full-screen ads could not be shown without system bars.';
      _logger.log(
        KitLogLevel.warning,
        message,
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      _setHealth(
        ModuleState.degraded,
        error: KitError(
          code: KitErrorCode.provider,
          message: message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  NavigationBarState _resolve() {
    if (_developerMode && _developerShowsEverywhere) {
      return NavigationBarState(
        visible: true,
        reason: NavigationBarReason.developer,
        routeName: _stack.isEmpty ? null : _stack.last.settings.name,
      );
    }
    for (final route in _stack.reversed) {
      final name = route.settings.name;
      final requests = _requests[route];
      if (requests != null && requests.isNotEmpty) {
        return NavigationBarState(
          visible: requests.last.visible,
          reason: NavigationBarReason.screen,
          routeName: name,
        );
      }
      final byName = name == null ? null : _routes[name];
      if (byName != null) {
        return NavigationBarState(
          visible: byName,
          reason: NavigationBarReason.route,
          routeName: name,
        );
      }
      // A dialog, bottom sheet or menu keeps the bar of the screen under it.
      if (route is PopupRoute) continue;
      return NavigationBarState(
        visible: _visibleByDefault,
        reason: NavigationBarReason.byDefault,
        routeName: name,
      );
    }
    return NavigationBarState(
      visible: _visibleByDefault,
      reason: NavigationBarReason.byDefault,
    );
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Navigation bar controller is not initialized, or has been '
            'disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'visible': _current.visible,
        'reason': _current.reason.name,
        'developerMode': _developerMode,
        'developerShowsEverywhere': _developerShowsEverywhere,
        'fullScreenOverlays': _fullScreenOverlays,
        'overlayNavigationBarVisible': overlayNavigationBarVisible,
        'supported': _navigationBar.isSupported,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}

final class _NavigationBarObserver extends NavigatorObserver {
  _NavigationBarObserver(this._controller);

  final NavigationBarController _controller;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _controller._pushed(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _controller._removed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _controller._removed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _controller._replaced(newRoute, oldRoute);
}
