import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'splash_ad.dart';
import 'splash_progress.dart';

/// Draws the splash for the current progress.
typedef SplashViewBuilder = Widget Function(
  BuildContext context,
  SplashProgress progress,
);

/// Runs an app's launch: its work, then the ad, then [onFinished].
///
/// [prepare], [resolveAd] and the ad's load share one budget, [maxWait], so
/// nothing — a slow startup, a consent form, an ad that does not fill — keeps
/// the user on the splash past it. The splash stays at least [minDuration],
/// shows 100% for [completionPause], and only then shows the ad, if it loaded
/// and the app is in the foreground. [onFinished] is called once, after the ad
/// closes; navigate from there.
///
/// Renders no `Scaffold`; put it in the route's own.
class SplashFlow extends StatefulWidget {
  /// Creates a splash.
  const SplashFlow({
    required this.onFinished,
    required this.builder,
    super.key,
    this.prepare,
    this.resolveAd,
    this.adExpected = false,
    this.minDuration = const Duration(milliseconds: 1500),
    this.maxWait = const Duration(seconds: 8),
    this.completionPause = const Duration(milliseconds: 300),
  });

  /// Called once when the splash is done and any ad has closed.
  final void Function(SplashOutcome outcome) onFinished;

  /// Draws the splash.
  final SplashViewBuilder builder;

  /// Work to wait for, such as reading where to go next. A failure or a
  /// timeout does not stop the splash.
  final Future<void> Function()? prepare;

  /// The ad for this launch, decided after [prepare]. Null, or a null result,
  /// shows no ad. Waiting for consent and the ad SDK belongs in here.
  final Future<SplashAdRequest?> Function()? resolveAd;

  /// Whether an ad is likely, so the disclosure shows from the first frame.
  /// [resolveAd]'s answer replaces it.
  final bool adExpected;

  /// The shortest time the splash stays.
  final Duration minDuration;

  /// The most [prepare], [resolveAd] and the ad's load may take together.
  final Duration maxWait;

  /// How long 100% shows before the ad or [onFinished].
  final Duration completionPause;

  @override
  State<SplashFlow> createState() => _SplashFlowState();
}

class _SplashFlowState extends State<SplashFlow> {
  final Stopwatch _elapsed = Stopwatch()..start();
  Timer? _ticker;
  late SplashProgress _progress;
  bool _loadingDone = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _progress = SplashProgress(
      value: 0,
      phase: SplashPhase.loading,
      adExpected: widget.adExpected,
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    unawaited(_run());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final left = widget.maxWait - _elapsed.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (_loadingDone) return;
    final total = widget.maxWait.inMilliseconds;
    final fraction = total <= 0
        ? 1.0
        : (_elapsed.elapsed.inMilliseconds / total).clamp(0.0, 1.0);
    // Eases out and stays short of full until the work is really done, so the
    // bar never sits at 100% while the app is still waiting.
    _update(value: 0.95 * (1 - math.pow(1 - fraction, 2)));
  }

  void _update({double? value, SplashPhase? phase, bool? adExpected}) {
    if (!mounted) return;
    setState(() {
      _progress = SplashProgress(
        value: value ?? _progress.value,
        phase: phase ?? _progress.phase,
        adExpected: adExpected ?? _progress.adExpected,
      );
    });
  }

  Future<void> _run() async {
    final prepare = widget.prepare;
    if (prepare != null) {
      try {
        await prepare().timeout(_remaining);
      } on Object {
        // Bounded on purpose: work that fails or hangs must not hold the user
        // here. The app still decides where to go in onFinished.
      }
    }

    SplashAdRequest? request;
    var status = SplashAdStatus.notRequested;
    KitError? error;
    final resolveAd = widget.resolveAd;
    if (resolveAd != null) {
      try {
        request = await resolveAd().timeout(_remaining);
      } on TimeoutException {
        status = SplashAdStatus.timedOut;
      } on Object catch (cause, stackTrace) {
        status = SplashAdStatus.failed;
        error = KitError(
          code: KitErrorCode.unknown,
          message: 'Deciding the splash ad failed: $cause',
          cause: cause,
          stackTrace: stackTrace,
        );
      }
    }
    _update(adExpected: request != null);

    var ready = false;
    if (request != null) {
      final (loadStatus, loadError) = await _load(request, _remaining);
      if (loadStatus == null) {
        ready = true;
      } else {
        status = loadStatus;
        error = loadError;
      }
    }

    final hold = widget.minDuration - _elapsed.elapsed;
    if (hold > Duration.zero) await Future<void>.delayed(hold);
    if (!mounted) return;
    _loadingDone = true;
    _update(value: 1);
    await Future<void>.delayed(widget.completionPause);
    if (!mounted) return;

    AdReward? reward;
    if (request != null && ready) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        // An ad that appears as the user comes back to the app reads as
        // unexpected, and full-screen ads cannot show in the background.
        status = SplashAdStatus.appInBackground;
      } else {
        _update(phase: SplashPhase.showingAd);
        final (showStatus, showReward, showError) = await _show(request);
        status = showStatus;
        reward = showReward;
        error = showError;
      }
    }

    if (!mounted || _finished) return;
    _finished = true;
    _ticker?.cancel();
    _update(phase: SplashPhase.finished);
    widget.onFinished(
      SplashOutcome(
        adStatus: status,
        elapsed: _elapsed.elapsed,
        placement: request?.placement,
        reward: reward,
        error: error,
      ),
    );
  }

  /// Null status when the ad is ready to show.
  static Future<(SplashAdStatus?, KitError?)> _load(
    SplashAdRequest request,
    Duration timeout,
  ) async {
    final provider = request.provider;
    final placement = request.placement;
    if (!provider.supportedFormats.contains(placement.format)) {
      return (
        SplashAdStatus.notReady,
        KitError(
          code: KitErrorCode.unsupported,
          message: '${provider.providerId} does not serve '
              '${placement.format.name} ads.',
        ),
      );
    }
    if (provider.isReady(placement)) return (null, null);
    if (timeout <= Duration.zero) return (SplashAdStatus.timedOut, null);
    try {
      final result = await provider.load(placement).timeout(timeout);
      final error = result.fold(onSuccess: (_) => null, onFailure: (e) => e);
      if (error != null) return (SplashAdStatus.failed, error);
    } on TimeoutException {
      return (
        provider.isReady(placement) ? null : SplashAdStatus.timedOut,
        null
      );
    }
    return (provider.isReady(placement) ? null : SplashAdStatus.notReady, null);
  }

  static Future<(SplashAdStatus, AdReward?, KitError?)> _show(
    SplashAdRequest request,
  ) async {
    final policy = request.policy;
    final result = policy == null
        ? await request.provider.show(request.placement)
        : await AdCoordinator(provider: request.provider, policy: policy)
            .show(request.placement);
    final error = result.fold(onSuccess: (_) => null, onFailure: (e) => e);
    if (error != null) return (SplashAdStatus.failed, null, error);
    final shown =
        result.fold(onSuccess: (value) => value, onFailure: (_) => null);
    return switch (shown?.status) {
      AdShowStatus.shown => (SplashAdStatus.shown, shown?.reward, null),
      AdShowStatus.blocked => (SplashAdStatus.blocked, null, null),
      _ => (SplashAdStatus.notReady, null, null),
    };
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}
