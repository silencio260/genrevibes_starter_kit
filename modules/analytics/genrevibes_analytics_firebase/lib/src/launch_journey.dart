import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'google_test_device.dart';

/// Sends one analytics event (name, parameters) to the providers.
typedef JourneySender = void Function(
  String name,
  Map<String, Object?> properties,
);

/// The path from a cold start to the app's home screen, measured as events,
/// plus launch-numbered copies of every event on that path.
///
/// - Every event the app routes through [deliver] gets `launch_number`: 1 for
///   the first cold start of this install, 2 for the second, and so on.
/// - On the first [LaunchJourneyConfig.prefixedLaunches] launches, every event
///   sent before the home screen first shows is also sent with an `l1_` /
///   `l2_` prefix (`sign_up` and `l1_sign_up`). After home, and on later
///   launches, only the normal names are sent. Revenue is never copied.
/// - Startup steps ([step]) carry `ms_since_launch`.
/// - Leaving before home is recorded (`splash_abandoned`, `journey_left_app`,
///   `journey_resumed`), and a launch that never reached home is reported on
///   the next one (`previous_launch_abandoned`).
///
/// Events from before analytics is ready are held and sent, in order, by
/// [attach]. On Google's test devices nothing is sent.
///
/// Use: [start] first thing in `main`, [attach] once the analytics pipeline
/// exists, [screenShown] from the screen tracker, and [deliver] from the app's
/// one analytics `track` method. See the package README.
final class LaunchJourney {
  /// A separate journey, for tests. Apps use [instance].
  @visibleForTesting
  LaunchJourney.forTesting({
    Future<String?> Function()? appInstanceId,
  }) : _appInstanceId = appInstanceId ?? _firebaseAppInstanceId;

  LaunchJourney._() : _appInstanceId = _firebaseAppInstanceId;

  /// The app's journey.
  static final LaunchJourney instance = LaunchJourney._();

  static const String _countKey = 'launch_journey.count';
  static const String _installKey = 'launch_journey.app_instance_id';
  static const String _lastLaunchKey = 'launch_journey.last_launch';

  /// Revenue events are never copied: a prefixed `ad_impression` (or any copy
  /// carrying `value` + `currency`) would count the same money twice in GA4.
  static const Set<String> _neverPrefixed = {'ad_impression'};

  final Future<String?> Function() _appInstanceId;
  final Stopwatch _clock = Stopwatch();
  final ValueNotifier<bool> _splashCapReached = ValueNotifier<bool>(false);
  final List<(String, Map<String, Object?>, JourneySender?)> _pending = [];
  final Set<String> _once = {};

  LaunchJourneyConfig _config = const LaunchJourneyConfig();
  KeyValueStore? _store;
  JourneySender? _send;
  bool _attached = false;
  bool _dropAll = false;
  int? _launchNumber;
  bool _windowOpen = true;
  bool _reachedHome = false;
  bool _splashDone = false;
  bool _launchAdShowing = false;
  String _lastStep = 'app_launch';
  int? _hiddenAtMs;
  Timer? _capTimer;
  AppLifecycleListener? _lifecycle;

  /// Starts the launch clock and records `app_launch`. Call first thing after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  void start([LaunchJourneyConfig config = const LaunchJourneyConfig()]) {
    if (_clock.isRunning) return;
    _config = config;
    _clock.start();
    _capTimer = Timer(config.splashCap, () => _splashCapReached.value = true);
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    step('app_launch');
  }

  int get _ms => _clock.elapsedMilliseconds;

  /// The configuration passed to [start].
  LaunchJourneyConfig get config => _config;

  /// The longest the splash may stay, from the launch.
  Duration get splashCap => _config.splashCap;

  /// True once [splashCap] has passed since the launch started.
  ValueListenable<bool> get splashCapReached => _splashCapReached;

  /// What is left of [splashCap] (zero once it has passed).
  Duration get splashRemaining {
    final left = _config.splashCap - _clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// This cold start's number on this install; null until [attach].
  int? get launchNumber => _launchNumber;

  /// Whether the path to home is still open on this launch.
  bool get beforeHome => _windowOpen;

  String? get _prefix {
    final number = _launchNumber;
    if (!_windowOpen || number == null || number > _config.prefixedLaunches) {
      return null;
    }
    return 'l${number}_';
  }

  // ── Delivery ──────────────────────────────────────────────────────────────

  /// Sends an app event through [send]: with `launch_number`, plus its
  /// prefixed copy while the path to home is open on the early launches.
  /// Route the app's single `track` method through this.
  void deliver(
    String name,
    Map<String, Object?> properties,
    JourneySender send,
  ) {
    if (_dropAll) return;
    if (!_attached) {
      _pending.add((name, properties, send));
      return;
    }
    _emit(name, properties, send);
  }

  void _emit(
    String name,
    Map<String, Object?> properties,
    JourneySender send,
  ) {
    final number = _launchNumber;
    final withLaunch =
        number == null ? properties : {...properties, 'launch_number': number};
    send(name, withLaunch);
    final prefix = _prefix;
    if (prefix == null || _neverPrefixed.contains(name)) return;
    send(
      '$prefix$name',
      {...withLaunch}
        ..remove('value')
        ..remove('currency'),
    );
  }

  /// A step on the path, with `ms_since_launch`.
  void step(String name, [Map<String, Object?> properties = const {}]) {
    if (_dropAll) return;
    _lastStep = name;
    final withTime = {...properties, 'ms_since_launch': _ms};
    final send = _send;
    if (!_attached || send == null) {
      _pending.add((name, withTime, null));
    } else {
      _emit(name, withTime, send);
    }
    _persist();
  }

  /// [step], at most once per launch.
  void stepOnce(String name, [Map<String, Object?> properties = const {}]) {
    if (_once.add(name)) step(name, properties);
  }

  /// A screen was shown (its `screen_view` name). Screens listed in
  /// [LaunchJourneyConfig.screenSteps] become steps, a name starting with
  /// [LaunchJourneyConfig.noInternetScreenPrefix] becomes `no_internet_shown`,
  /// and [LaunchJourneyConfig.homeScreen] closes the path.
  void screenShown(String name) {
    if (name != _config.splashScreen) _splashDone = true;
    if (!_windowOpen) return;
    if (name == _config.homeScreen) {
      homeReached();
      return;
    }
    final noInternet = _config.noInternetScreenPrefix;
    if (noInternet != null && name.startsWith(noInternet)) {
      step('no_internet_shown', {'source': name.substring(noInternet.length)});
      return;
    }
    final stepName = _config.screenSteps[name];
    if (stepName != null) stepOnce(stepName);
  }

  /// The home screen showed for the first time this launch: the end of the
  /// path. [screenShown] calls it for [LaunchJourneyConfig.homeScreen].
  void homeReached() {
    if (!_windowOpen) return;
    step('home_reached');
    _reachedHome = true;
    _windowOpen = false;
    _persist();
  }

  // ── Splash and the launch ad ──────────────────────────────────────────────

  /// The launch (app-open) ad is on screen.
  void launchAdShown() {
    _launchAdShowing = true;
    stepOnce('launch_ad_shown');
  }

  /// The launcher splash handed over. [adStatus] is the kit's
  /// `SplashAdStatus` name.
  void splashFinished({
    required String adStatus,
    required Duration elapsed,
    required bool adWasShown,
  }) {
    _launchAdShowing = false;
    if (adWasShown) stepOnce('launch_ad_closed');
    stepOnce('splash_finished', {
      'ad_status': adStatus,
      'splash_ms': elapsed.inMilliseconds,
    });
  }

  // ── Leaving and coming back ───────────────────────────────────────────────

  void _onHide() {
    if (!_windowOpen) return;
    _hiddenAtMs = _ms;
    final reached = _lastStep;
    step(_splashDone ? 'journey_left_app' : 'splash_abandoned', {
      'step_reached': reached,
      'during_launch_ad': _launchAdShowing,
    });
  }

  void _onShow() {
    final hiddenAt = _hiddenAtMs;
    _hiddenAtMs = null;
    if (!_windowOpen || hiddenAt == null) return;
    step('journey_resumed', {'away_ms': _ms - hiddenAt});
  }

  // ── Attaching to analytics ────────────────────────────────────────────────

  /// Connects the journey to analytics and sends the held events. Called
  /// again after a startup retry, it only swaps the sender.
  ///
  /// [store] keeps the launch count and the last launch between cold starts
  /// (use the app's persistent store). [alreadyOnboarded]: an install that
  /// finished onboarding before this tracking existed is an upgrade, counted
  /// as launch `prefixedLaunches + 1`. [testDevice] defaults to
  /// [GoogleTestDevice.check]; on a test device everything is dropped.
  Future<void> attach({
    required JourneySender send,
    required KeyValueStore store,
    required bool alreadyOnboarded,
    bool? testDevice,
  }) async {
    if (_attached) {
      _send = send;
      return;
    }
    if (testDevice ?? await GoogleTestDevice.check()) {
      _dropAll = true;
      _pending.clear();
      _attached = true;
      return;
    }
    _store = store;
    final previous = await _readString(_lastLaunchKey);
    final storedInstall = await _readString(_installKey);
    final storedCount = await _readInt(_countKey) ?? 0;
    String? install;
    try {
      install = await _appInstanceId();
    } on Object {
      install = null;
    }

    final int number;
    if (storedInstall == null) {
      // First run of this tracking: a new install, or an older version updated.
      number = alreadyOnboarded ? _config.prefixedLaunches + 1 : 1;
    } else if (install != null && install != storedInstall) {
      // Android restored the old preferences into a fresh install.
      number = 1;
    } else {
      number = storedCount + 1;
    }
    _launchNumber = number;
    unawaited(store.setInt(_countKey, number));
    final installToStore = install ?? storedInstall;
    if (installToStore != null) {
      unawaited(store.setString(_installKey, installToStore));
    }

    _send = send;
    _attached = true;
    final held = List.of(_pending);
    _pending.clear();
    for (final (name, properties, sender) in held) {
      _emit(name, properties, sender ?? send);
    }

    final abandoned = number > 1 ? _parseLastLaunch(previous) : null;
    if (abandoned != null && !abandoned.reachedHome) {
      step('previous_launch_abandoned', {
        'previous_launch': abandoned.launch,
        'step_reached': abandoned.step,
        'previous_ms': abandoned.ms,
      });
    }
    _persist();
  }

  /// Startup failed before the analytics pipeline existed: sends the held
  /// events straight to Firebase so the failure is still seen.
  Future<void> attachDirectToFirebase({
    required KeyValueStore store,
    bool? testDevice,
  }) =>
      attach(
        send: _firebaseSend,
        store: store,
        testDevice: testDevice,
        alreadyOnboarded: false,
      );

  static Future<String?> _firebaseAppInstanceId() =>
      FirebaseAnalytics.instance.appInstanceId;

  static void _firebaseSend(String name, Map<String, Object?> properties) {
    final parameters = <String, Object>{
      for (final MapEntry(:key, :value) in properties.entries)
        if (value != null)
          key: switch (value) {
            // As the Firebase sink: GA4 shows integer flags as "(not set)".
            final bool flag => flag ? 'true' : 'false',
            final num number => number,
            _ => value.toString(),
          },
    };
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: name, parameters: parameters)
          .catchError((Object _) {}),
    );
  }

  // ── The last launch, kept on the phone ────────────────────────────────────

  void _persist() {
    final number = _launchNumber;
    final store = _store;
    if (!_attached || _dropAll || number == null || store == null) return;
    final record = '$number|${_reachedHome ? 1 : 0}|$_ms|$_lastStep';
    unawaited(store.setString(_lastLaunchKey, record));
  }

  static ({int launch, bool reachedHome, int ms, String step})?
      _parseLastLaunch(String? record) {
    if (record == null) return null;
    final parts = record.split('|');
    if (parts.length < 4) return null;
    final launch = int.tryParse(parts[0]);
    final ms = int.tryParse(parts[2]);
    if (launch == null || ms == null) return null;
    return (
      launch: launch,
      reachedHome: parts[1] == '1',
      ms: ms,
      step: parts.sublist(3).join('|'),
    );
  }

  Future<String?> _readString(String key) async {
    try {
      return (await _store!.getString(key)).fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
    } on Object {
      return null;
    }
  }

  Future<int?> _readInt(String key) async {
    try {
      return (await _store!.getInt(key)).fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
    } on Object {
      return null;
    }
  }

  /// Stops the timers and lifecycle listener.
  @visibleForTesting
  void dispose() {
    _capTimer?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// What an app's launch path looks like, for [LaunchJourney.start].
@immutable
final class LaunchJourneyConfig {
  /// Creates a launch path description.
  const LaunchJourneyConfig({
    this.splashCap = const Duration(seconds: 5),
    this.prefixedLaunches = 2,
    this.splashScreen = 'splash',
    this.homeScreen = 'tab_home',
    this.noInternetScreenPrefix = 'no_internet_',
    this.screenSteps = const {
      'splash': 'splash_shown',
      'language_select': 'language_select_shown',
    },
  });

  /// The longest the app's splash may stay before it moves on. The journey
  /// only exposes it ([LaunchJourney.splashCapReached]); the app enforces it.
  final Duration splashCap;

  /// Launches whose pre-home events also get the `l<n>_` prefix.
  final int prefixedLaunches;

  /// The splash's screen name. Any other screen means the splash is over.
  final String splashScreen;

  /// The screen name that ends the path (`home_reached`).
  final String homeScreen;

  /// Screen names starting with this are reported as `no_internet_shown`
  /// with the rest of the name as `source`. Null to turn this off.
  final String? noInternetScreenPrefix;

  /// Screen name → step event, recorded the first time each shows.
  final Map<String, String> screenSteps;
}
