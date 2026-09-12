import 'dart:async';

import 'package:flutter/material.dart';

import '../model/onboarding_action.dart';
import '../model/onboarding_flow_options.dart';
import '../model/onboarding_page.dart';
import 'onboarding_page_indicator.dart';

/// Builds a page's artwork, title and description, replacing the default.
typedef OnboardingPageBuilder = Widget Function(
  BuildContext context,
  OnboardingPage page,
  int index,
);

/// Builds the controls, replacing the default layouts.
typedef OnboardingControlsBuilder = Widget Function(
  BuildContext context,
  OnboardingFlowControls controls,
);

/// Reports an action that failed or timed out.
typedef OnboardingActionErrorCallback = void Function(
  OnboardingAction action,
  Object error,
  StackTrace stackTrace,
);

/// A configurable onboarding flow: any number of pages, an optional ad slot,
/// and a sequence of actions to run when it finishes or is skipped.
///
/// By default ([OnboardingPresentation.screens]) every page is a complete
/// screen with its own controls and, when it has one, its own ad, and swipes
/// in as a unit — so a flow can mix screens built around an ad with
/// full-screen ones, and neither looks like the other with something missing.
///
/// Everything an app varies is a parameter: the pages, whether and where each
/// shows an ad, each page's screen layout or a builder for the whole screen,
/// the control layout or a builder replacing it, labels, style, and what
/// happens at the end — open a paywall, mark onboarding complete, navigate, any
/// mix of them, or anything else an [OnboardingAction] can do.
///
/// Like `OnboardingView`, it renders no `Scaffold`, so a host can place it in
/// a route, a sheet or a dialog.
final class OnboardingFlow extends StatefulWidget {
  /// Creates a flow.
  const OnboardingFlow({
    required this.pages,
    super.key,
    this.presentation = OnboardingPresentation.screens,
    this.finishActions = const <OnboardingAction>[],
    this.skipActions,
    this.skipBehavior = OnboardingSkipBehavior.jumpToLastPage,
    this.controlsLayout = OnboardingControlsLayout.row,
    this.adSlot,
    this.labels = const OnboardingLabels(),
    this.style = const OnboardingFlowStyle(),
    this.screenBuilder,
    this.pageBuilder,
    this.controlsBuilder,
    this.onPageChanged,
    this.onActionError,
    this.onFinished,
    this.allowSwipe = true,
    this.initialPage = 0,
  });

  /// Pages in display order. Must not be empty.
  final List<OnboardingPage> pages;

  /// Whether each page is a whole screen, or pages share controls and an ad
  /// area.
  final OnboardingPresentation presentation;

  /// Run in order when the user finishes the last page.
  final List<OnboardingAction> finishActions;

  /// Run in order when skipping with [OnboardingSkipBehavior.finish]. Null
  /// runs [finishActions] instead.
  final List<OnboardingAction>? skipActions;

  /// What the skip control does.
  final OnboardingSkipBehavior skipBehavior;

  /// The default control arrangement. A page's own `controlsLayout` wins, and
  /// [controlsBuilder] replaces both.
  final OnboardingControlsLayout controlsLayout;

  /// An ad shown on pages whose `showAd` is true. Null shows none.
  final OnboardingAdSlot? adSlot;

  /// Control labels.
  final OnboardingLabels labels;

  /// Visual overrides.
  final OnboardingFlowStyle style;

  /// Arranges every screen, in the screens presentation. A page's own
  /// `screenBuilder` wins.
  final OnboardingScreenBuilder? screenBuilder;

  /// Replaces the default artwork, title and description of a page.
  final OnboardingPageBuilder? pageBuilder;

  /// Replaces the default controls.
  final OnboardingControlsBuilder? controlsBuilder;

  /// Called whenever the visible page changes, including the first.
  final ValueChanged<int>? onPageChanged;

  /// Called for each action that fails or times out.
  final OnboardingActionErrorCallback? onActionError;

  /// Called after a sequence of actions ran without stopping.
  final VoidCallback? onFinished;

  /// Whether the user can swipe between pages.
  final bool allowSwipe;

  /// The page shown first.
  final int initialPage;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _controller =
      PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;
  bool _busy = false;

  int get _count => widget.pages.length;

  bool get _isLastPage => _index == _count - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPageChanged?.call(_index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  void _goTo(int index) {
    if (!_controller.hasClients) return;
    unawaited(
      _controller.animateToPage(
        index.clamp(0, _count - 1),
        duration: widget.style.pageTransitionDuration,
        curve: widget.style.pageTransitionCurve,
      ),
    );
  }

  void _next() {
    if (_busy) return;
    if (_isLastPage) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _skip() {
    if (_busy) return;
    switch (widget.skipBehavior) {
      case OnboardingSkipBehavior.hidden:
        return;
      case OnboardingSkipBehavior.jumpToLastPage:
        _goTo(_count - 1);
      case OnboardingSkipBehavior.finish:
        unawaited(_run(widget.skipActions ?? widget.finishActions));
    }
  }

  void _finish() => unawaited(_run(widget.finishActions));

  Future<void> _run(List<OnboardingAction> actions) async {
    if (_busy) return;
    setState(() => _busy = true);
    var ranToEnd = true;
    for (final action in actions) {
      if (!mounted) return;
      try {
        final running = Future<void>.sync(() => action.run(context));
        final timeout = action.timeout;
        await (timeout == null ? running : running.timeout(timeout));
      } on Object catch (error, stackTrace) {
        widget.onActionError?.call(action, error, stackTrace);
        if (!action.continueOnError) {
          ranToEnd = false;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ranToEnd) widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.pages.isNotEmpty, 'Onboarding requires at least one page.');
    final screens = widget.presentation == OnboardingPresentation.screens;
    final pages = PageView.builder(
      controller: _controller,
      physics: widget.allowSwipe && !_busy
          ? null
          : const NeverScrollableScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemCount: _count,
      itemBuilder: screens ? _screen : _content,
    );
    return ColoredBox(
      color:
          widget.style.backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: screens ? pages : _shared(context, pages),
    );
  }

  // ------------------------------------------------------------- pieces

  Widget _content(BuildContext context, int index) {
    final page = widget.pages[index];
    return widget.pageBuilder?.call(context, page, index) ??
        _OnboardingFlowPage(page: page, style: widget.style);
  }

  OnboardingFlowControls _controls(int index) => OnboardingFlowControls(
        pageIndex: index,
        pageCount: _count,
        busy: _busy,
        next: _next,
        finish: _finish,
        goTo: _goTo,
        skip:
            widget.skipBehavior == OnboardingSkipBehavior.hidden ? null : _skip,
      );

  Widget _controlsView(
    BuildContext context,
    OnboardingFlowControls controls, {
    OnboardingControlsLayout? layout,
    EdgeInsets? padding,
  }) =>
      widget.controlsBuilder?.call(context, controls) ??
      _DefaultControls(
        controls: controls,
        layout: layout ?? widget.controlsLayout,
        labels: widget.labels,
        style: widget.style,
        padding: padding ?? widget.style.controlsPadding,
      );

  // ------------------------------------------------------------ screens

  Widget _screen(BuildContext context, int index) {
    final page = widget.pages[index];
    final style = widget.style;
    final slot = widget.adSlot;
    final immersive = page.layout == OnboardingScreenLayout.immersive;
    final ad = slot != null && page.showAd && !immersive
        ? _screenAd(context, slot, index)
        : null;
    final controls = _controls(index);
    final parts = OnboardingScreenParts(
      page: page,
      controls: controls,
      controlsView: _controlsView(
        context,
        controls,
        layout: page.controlsLayout,
        padding: ad == null ? style.adFreeControlsPadding : null,
      ),
      content: _content(context, index),
      ad: ad,
    );

    final builder = page.screenBuilder ?? widget.screenBuilder;
    if (builder != null) return builder(context, parts);
    if (immersive) return _ImmersiveScreen(parts: parts, style: style);

    final position = slot?.position ?? OnboardingAdPosition.bottom;
    if (page.layout == OnboardingScreenLayout.edgeToEdge) {
      return _EdgeToEdgeScreen(parts: parts, style: style, adPosition: position);
    }
    return SafeArea(
      child: Column(
        children: <Widget>[
          Expanded(child: parts.content),
          if (ad != null && position == OnboardingAdPosition.aboveControls) ad,
          parts.controlsView,
          if (ad != null && position == OnboardingAdPosition.bottom) ad,
        ],
      ),
    );
  }

  /// A screen's own ad.
  ///
  /// With a reserved height the space is part of the screen from its first
  /// frame, loaded or not, so nothing moves when the ad arrives. Without one,
  /// an ad that arrives after the screen is showing grows into place.
  Widget _screenAd(BuildContext context, OnboardingAdSlot slot, int index) {
    final ad = KeyedSubtree(
      key: ValueKey<String>('onboarding_ad_$index'),
      child: slot.builder(context, index),
    );
    final reserved = slot.reservedHeight;
    if (reserved != null) {
      return SizedBox(width: double.infinity, height: reserved, child: ad);
    }
    if (slot.sizeAnimation == Duration.zero) return ad;
    return AnimatedSize(
      duration: slot.sizeAnimation,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: ad,
    );
  }

  // ------------------------------------------------------ shared controls

  Widget _shared(BuildContext context, Widget pages) {
    final slot = widget.adSlot;
    final page = widget.pages[_index];
    final showAd = slot != null && page.showAd;
    return SafeArea(
      child: Column(
        children: <Widget>[
          Expanded(child: pages),
          if (slot != null && slot.position == OnboardingAdPosition.aboveControls)
            _sharedAdArea(context, slot, visible: showAd),
          _controlsView(context, _controls(_index), layout: page.controlsLayout),
          if (slot != null && slot.position == OnboardingAdPosition.bottom)
            _sharedAdArea(context, slot, visible: showAd),
        ],
      ),
    );
  }

  /// The shared ad, or nothing on a page without one. Changes in height
  /// animate, so moving between pages with and without an ad does not jump.
  Widget _sharedAdArea(
    BuildContext context,
    OnboardingAdSlot slot, {
    required bool visible,
  }) {
    final area = visible
        ? KeyedSubtree(
            key: slot.oneAdPerPage
                ? ValueKey<int>(_index)
                : const ValueKey<String>('onboarding_ad'),
            child: _reserve(slot, slot.builder(context, _index)),
          )
        : const SizedBox(width: double.infinity);
    if (slot.sizeAnimation == Duration.zero) return area;
    return AnimatedSize(
      duration: slot.sizeAnimation,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: area,
    );
  }

  Widget _reserve(OnboardingAdSlot slot, Widget ad) {
    final reserved = slot.reservedHeight;
    return reserved == null
        ? ad
        : SizedBox(width: double.infinity, height: reserved, child: ad);
  }
}

class _OnboardingFlowPage extends StatelessWidget {
  const _OnboardingFlowPage({required this.page, required this.style});

  final OnboardingPage page;
  final OnboardingFlowStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artwork = page.artwork;
    if (page.template == OnboardingTemplate.custom && artwork != null) {
      return artwork(context);
    }
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: style.titleStyle ?? theme.textTheme.headlineSmall,
        ),
        SizedBox(height: style.textSpacing),
        Text(
          page.description,
          textAlign: TextAlign.center,
          style: style.descriptionStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
    if (page.template == OnboardingTemplate.standard && artwork != null) {
      return Padding(
        padding: style.pagePadding,
        child: Column(
          children: <Widget>[
            Expanded(flex: style.artworkFlex, child: artwork(context)),
            SizedBox(height: style.textSpacing),
            Expanded(
              flex: style.textFlex,
              child: SingleChildScrollView(child: text),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: style.pagePadding,
      child: Center(child: SingleChildScrollView(child: text)),
    );
  }
}

/// Artwork across the top edge to edge, taking whatever height the text,
/// controls and ad leave.
class _EdgeToEdgeScreen extends StatelessWidget {
  const _EdgeToEdgeScreen({
    required this.parts,
    required this.style,
    required this.adPosition,
  });

  final OnboardingScreenParts parts;
  final OnboardingFlowStyle style;
  final OnboardingAdPosition adPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = parts.page;
    final artwork = page.artwork;
    final ad = parts.ad;
    final background = style.backgroundColor ?? theme.colorScheme.surface;
    return SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (artwork != null) artwork(context),
                if (style.artworkFadeHeight > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: style.artworkFadeHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              background.withAlpha(0),
                              background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              style.pagePadding.left,
              style.textSpacing,
              style.pagePadding.right,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: style.titleStyle ?? theme.textTheme.headlineSmall,
                ),
                SizedBox(height: style.textSpacing),
                Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: style.descriptionStyle ??
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (ad != null && adPosition == OnboardingAdPosition.aboveControls)
            ad,
          parts.controlsView,
          if (ad != null && adPosition == OnboardingAdPosition.bottom) ad,
        ],
      ),
    );
  }
}

/// Artwork edge to edge, with the text and controls over a fade at the bottom.
class _ImmersiveScreen extends StatelessWidget {
  const _ImmersiveScreen({required this.parts, required this.style});

  final OnboardingScreenParts parts;
  final OnboardingFlowStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = parts.page;
    final artwork = page.artwork;
    final scrim = style.immersiveScrimColor;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (artwork != null) artwork(context),
        Align(
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[scrim.withAlpha(0), scrim],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  style.pagePadding.left,
                  48,
                  style.pagePadding.right,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: (style.titleStyle ?? theme.textTheme.headlineSmall)
                          ?.copyWith(color: style.immersiveTextColor),
                    ),
                    SizedBox(height: style.textSpacing),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style:
                          (style.descriptionStyle ?? theme.textTheme.bodyMedium)
                              ?.copyWith(color: style.immersiveTextColor),
                    ),
                    parts.controlsView,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultControls extends StatelessWidget {
  const _DefaultControls({
    required this.controls,
    required this.layout,
    required this.labels,
    required this.style,
    required this.padding,
  });

  final OnboardingFlowControls controls;
  final OnboardingControlsLayout layout;
  final OnboardingLabels labels;
  final OnboardingFlowStyle style;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final indicator = OnboardingPageIndicator(
      count: controls.pageCount,
      activeIndex: controls.pageIndex,
      activeColor: style.activeIndicatorColor,
      inactiveColor: style.inactiveIndicatorColor,
    );
    const busy = SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final primaryLabel = controls.isLastPage ? labels.finish : labels.next;
    final onPrimary = controls.busy ? null : controls.next;
    final skip = controls.isLastPage ? null : controls.skip;

    Widget fullWidthButton() => SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: style.buttonStyle,
            onPressed: onPrimary,
            child: controls.busy ? busy : Text(primaryLabel),
          ),
        );

    Widget skipButton(VoidCallback onSkip) => TextButton(
          style: style.skipButtonStyle,
          onPressed: controls.busy ? null : onSkip,
          child: Text(labels.skip),
        );

    final content = switch (layout) {
      OnboardingControlsLayout.row => controls.isLastPage
          ? fullWidthButton()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (skip != null)
                  skipButton(skip)
                else
                  const SizedBox(width: 64),
                indicator,
                TextButton(
                  style: style.textButtonStyle,
                  onPressed: onPrimary,
                  child: Text(labels.next),
                ),
              ],
            ),
      OnboardingControlsLayout.stacked => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            indicator,
            const SizedBox(height: 4),
            TextButton(
              style: style.textButtonStyle,
              onPressed: onPrimary,
              child: controls.busy ? busy : Text(primaryLabel),
            ),
            if (skip != null) skipButton(skip),
          ],
        ),
      OnboardingControlsLayout.fullWidthButton => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            indicator,
            const SizedBox(height: 16),
            fullWidthButton(),
            if (skip != null) skipButton(skip),
          ],
        ),
    };
    return Padding(padding: padding, child: content);
  }
}
