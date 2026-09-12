import 'dart:async';

import 'package:flutter/material.dart';

import '../model/onboarding_action.dart';
import '../model/onboarding_flow_options.dart';
import '../model/onboarding_page.dart';
import 'onboarding_page_indicator.dart';

/// Builds a whole page, replacing the default layout.
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
/// Everything an app varies is a parameter: the pages, where the ad sits and
/// whether each page shows it, the control layout or a builder replacing it,
/// a builder replacing the page layout, labels, style, and what happens at the
/// end — open a paywall, mark onboarding complete, navigate, any mix of them,
/// or anything else an [OnboardingAction] can do.
///
/// Like `OnboardingView`, it renders no `Scaffold`, so a host can place it in
/// a route, a sheet or a dialog.
final class OnboardingFlow extends StatefulWidget {
  /// Creates a flow.
  const OnboardingFlow({
    required this.pages,
    super.key,
    this.finishActions = const <OnboardingAction>[],
    this.skipActions,
    this.skipBehavior = OnboardingSkipBehavior.jumpToLastPage,
    this.controlsLayout = OnboardingControlsLayout.row,
    this.adSlot,
    this.labels = const OnboardingLabels(),
    this.style = const OnboardingFlowStyle(),
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

  /// Run in order when the user finishes the last page.
  final List<OnboardingAction> finishActions;

  /// Run in order when skipping with [OnboardingSkipBehavior.finish]. Null
  /// runs [finishActions] instead.
  final List<OnboardingAction>? skipActions;

  /// What the skip control does.
  final OnboardingSkipBehavior skipBehavior;

  /// The default control arrangement. Ignored when [controlsBuilder] is set.
  final OnboardingControlsLayout controlsLayout;

  /// An ad shown on pages whose `showAd` is true. Null shows none.
  final OnboardingAdSlot? adSlot;

  /// Control labels.
  final OnboardingLabels labels;

  /// Visual overrides.
  final OnboardingFlowStyle style;

  /// Replaces the default page layout.
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
    final theme = Theme.of(context);
    final style = widget.style;
    final slot = widget.pages[_index].showAd ? widget.adSlot : null;
    final controls = OnboardingFlowControls(
      pageIndex: _index,
      pageCount: _count,
      busy: _busy,
      next: _next,
      finish: _finish,
      goTo: _goTo,
      skip: widget.skipBehavior == OnboardingSkipBehavior.hidden ? null : _skip,
    );
    return ColoredBox(
      color: style.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: widget.allowSwipe && !_busy
                    ? null
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: _count,
                itemBuilder: (context, index) {
                  final page = widget.pages[index];
                  return widget.pageBuilder?.call(context, page, index) ??
                      _OnboardingFlowPage(page: page, style: style);
                },
              ),
            ),
            if (slot != null && slot.position == OnboardingAdPosition.aboveControls)
              _ad(context, slot),
            widget.controlsBuilder?.call(context, controls) ??
                _DefaultControls(
                  controls: controls,
                  layout: widget.controlsLayout,
                  labels: widget.labels,
                  style: style,
                ),
            if (slot != null && slot.position == OnboardingAdPosition.bottom)
              _ad(context, slot),
          ],
        ),
      ),
    );
  }

  Widget _ad(BuildContext context, OnboardingAdSlot slot) {
    final ad = KeyedSubtree(
      key: slot.oneAdPerPage
          ? ValueKey<int>(_index)
          : const ValueKey<String>('onboarding_ad'),
      child: slot.builder(context, _index),
    );
    final reserved = slot.reservedHeight;
    return reserved == null
        ? ad
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: reserved),
            child: ad,
          );
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

class _DefaultControls extends StatelessWidget {
  const _DefaultControls({
    required this.controls,
    required this.layout,
    required this.labels,
    required this.style,
  });

  final OnboardingFlowControls controls;
  final OnboardingControlsLayout layout;
  final OnboardingLabels labels;
  final OnboardingFlowStyle style;

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
    return Padding(padding: style.controlsPadding, child: content);
  }
}
