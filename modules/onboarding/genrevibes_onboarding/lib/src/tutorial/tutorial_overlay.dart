import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'tutorial_controller.dart';
import 'tutorial_step.dart';

/// Place last in a bounded Stack above the content being explained. This
/// widget does not create a route, global OverlayEntry, or storage provider.
/// Only one tutorial should be visible on a given app surface at a time.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay(
      {super.key,
      required this.controller,
      required this.steps,
      required this.labels,
      this.enabled = true,
      this.showPrevious = false,
      this.onFinish,
      this.onSkip,
      this.onError,
      this.cardBuilder,
      this.scrimColor = const Color(0x99000000),
      this.highlightColor = Colors.white,
      this.cornerRadius = 12,
      this.maxCardWidth = 560});

  final TutorialController controller;

  /// Same stable IDs and order as the controller; content may rebuild for a
  /// locale change or contextual recovery without changing saved progress.
  final List<TutorialStep> steps;
  final TutorialLabels labels;

  /// False removes the overlay while a drawer, route or native surface owns UI.
  final bool enabled;
  final bool showPrevious;

  /// Overrides default completion; the host must complete/skip the controller
  /// after its own navigation or other required work succeeds.
  final FutureOr<void> Function()? onFinish;
  final FutureOr<void> Function()? onSkip;
  final ValueChanged<KitError>? onError;

  /// Retains shared targeting, touch policy and safe positioning with custom UI.
  final Widget Function(
      BuildContext context, TutorialStep step, Widget controls)? cardBuilder;
  final Color scrimColor;
  final Color highlightColor;
  final double cornerRadius;
  final double maxCardWidth;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  Rect? _target;
  String? _measuredStep;
  bool _measurementScheduled = false;
  bool _actionBusy = false;
  int _actionGeneration = 0;

  bool get _visible =>
      widget.enabled &&
      widget.controller.isActive &&
      !widget.controller.isPaused;
  TutorialStep get _step => widget.steps[widget.controller.currentIndex];

  @override
  void initState() {
    super.initState();
    _validateSteps();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _actionGeneration++;
      _actionBusy = false;
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _validateSteps();
    if (oldWidget.controller != widget.controller || !_visible) {
      _target = null;
      _measuredStep = null;
    }
  }

  void _validateSteps() {
    final ids = widget.controller.stepIds;
    if (widget.steps.length != ids.length ||
        List.generate(ids.length, (index) => index)
            .any((index) => widget.steps[index].id != ids[index])) {
      throw ArgumentError(
          'TutorialOverlay steps must match controller.stepIds in order.');
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Measure after layout and during naturally occurring animation/scroll
  /// frames. Rescheduling the callback alone does not force idle frames.
  void _measureAfterFrame() {
    if (_measurementScheduled || !_visible) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || !_visible) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final id = _step.id;
      Rect? target;
      try {
        target = _step.target?.resolve(context);
        if (target != null) {
          target = target.intersect(Offset.zero & box.size);
          if (target.isEmpty || !target.isFinite) target = null;
        }
      } catch (_) {
        // A disposed/moving target does not trap the user behind the scrim.
        target = null;
      }
      if (_target != target || _measuredStep != id) {
        setState(() {
          _target = target;
          _measuredStep = id;
        });
      }
      _measureAfterFrame();
    });
  }

  Future<void> _invoke(FutureOr<void> Function() action) async {
    if (_actionBusy || widget.controller.isBusy) return;
    final generation = _actionGeneration;
    setState(() => _actionBusy = true);
    try {
      await action();
    } catch (error, stack) {
      if (mounted && generation == _actionGeneration) {
        widget.onError?.call(error is KitError
            ? error
            : KitError(
                code: KitErrorCode.unknown,
                message: 'Tutorial action failed.',
                cause: error,
                stackTrace: stack));
      }
    } finally {
      if (mounted && generation == _actionGeneration) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _result(Future<KitResult<void>> operation) async {
    final owner = widget.controller;
    final result = await operation;
    if (!mounted || widget.controller != owner) return;
    if (result case KitFailure(:final error)) widget.onError?.call(error);
  }

  Future<void> _next() async {
    if (widget.controller.isLastStep && widget.onFinish != null) {
      await widget.onFinish!();
    } else {
      await _result(widget.controller.next());
    }
  }

  Future<void> _skip() async {
    if (widget.onSkip != null) {
      await widget.onSkip!();
    } else {
      await _result(widget.controller.skip());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    _measureAfterFrame();
    final step = _step;
    final rect = _measuredStep == step.id ? _target : null;
    final busy = _actionBusy || widget.controller.isBusy;
    final controls = Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (step.allowSkip)
            TextButton(
                onPressed: busy ? null : () => _invoke(_skip),
                child: Text(widget.labels.skip)),
          if (widget.showPrevious && !widget.controller.isFirstStep)
            TextButton(
                onPressed: busy
                    ? null
                    : () =>
                        _invoke(() => _result(widget.controller.previous())),
                child: Text(widget.labels.previous)),
          if (step.showNext && step.onPrimary != null)
            TextButton(
                onPressed: busy ? null : () => _invoke(_next),
                child: Text(widget.labels.next)),
          FilledButton(
              onPressed: busy ? null : () => _invoke(step.onPrimary ?? _next),
              child: Text(
                  step.primaryLabel ??
                      (widget.controller.isLastStep
                          ? widget.labels.finish
                          : widget.labels.next),
                  textAlign: TextAlign.center)),
        ]);
    final card = widget.cardBuilder?.call(context, step, controls) ??
        Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                      header: true,
                      child: Text(step.title,
                          style: Theme.of(context).textTheme.titleLarge)),
                  const SizedBox(height: 8),
                  Text(step.body),
                  const SizedBox(height: 12),
                  controls,
                ]));
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final media = MediaQuery.of(context);
      final padding = media.padding;
      final renderBox = context.findRenderObject();
      final globalTop = renderBox is RenderBox && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero).dy
          : 0.0;
      // Compare global keyboard bounds with this overlay, rather than blindly
      // subtracting insets a second time from an already-resized Scaffold body.
      final visibleBottom = math.min(
          size.height, media.size.height - media.viewInsets.bottom - globalTop);
      final left = padding.left + 16;
      final right = size.width - padding.right - 16;
      final top = padding.top + 16;
      final bottom = visibleBottom - padding.bottom - 16;
      final available = math.max(0.0, bottom - top);
      var placement = step.placement;
      if (placement == TutorialCardPlacement.automatic) {
        placement = rect == null
            ? TutorialCardPlacement.top
            : rect.center.dy > size.height / 2
                ? TutorialCardPlacement.top
                : TutorialCardPlacement.bottom;
      }
      double? cardTop = top;
      double? cardBottom;
      var maxHeight = available;
      if (placement == TutorialCardPlacement.top && rect != null) {
        maxHeight = math.min(available, math.max(0, rect.top - 16 - top));
      } else if (placement == TutorialCardPlacement.bottom) {
        cardTop = null;
        cardBottom = size.height - bottom;
        if (rect != null) {
          maxHeight =
              math.min(available, math.max(0, bottom - rect.bottom - 16));
        }
      }
      // Very tight or missing-target layouts retain a scrollable card and its
      // escape controls, even if the card must overlap the target.
      if (maxHeight < math.min(120, available)) maxHeight = available;
      final center = placement == TutorialCardPlacement.center;
      final cardWidget = ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: maxHeight, maxWidth: widget.maxCardWidth),
        child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(child: card)),
      );
      final passThrough =
          step.interaction == TutorialInteraction.targetOnly && !busy
              ? rect
              : null;
      return Stack(children: [
        Positioned.fill(
            child: IgnorePointer(
                child: CustomPaint(
                    painter: _TutorialSpotlightPainter(rect, widget.scrimColor,
                        widget.highlightColor, widget.cornerRadius)))),
        if (step.interaction != TutorialInteraction.anywhere || busy)
          ..._blockers(passThrough, size),
        if (step.decorationBuilder != null)
          Positioned.fill(
              child: IgnorePointer(
                  child: ExcludeSemantics(
                      child: step.decorationBuilder!(context)))),
        if (center)
          Positioned(
              left: left,
              right: math.max(0, size.width - right),
              top: top,
              bottom: math.max(0, size.height - bottom),
              child: Center(child: cardWidget))
        else
          Positioned(
              left: left,
              right: math.max(0, size.width - right),
              top: cardTop,
              bottom: cardBottom,
              child: Align(alignment: Alignment.topCenter, child: cardWidget)),
      ]);
    });
  }

  List<Widget> _blockers(Rect? hole, Size size) {
    Widget block(Rect rect) => Positioned.fromRect(
        rect: rect,
        child:
            const ModalBarrier(dismissible: false, color: Colors.transparent));
    if (hole == null) return [block(Offset.zero & size)];
    return [
      block(Rect.fromLTRB(0, 0, size.width, hole.top)),
      block(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
      block(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
      block(Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom))
    ];
  }
}

class _TutorialSpotlightPainter extends CustomPainter {
  const _TutorialSpotlightPainter(
      this.target, this.scrim, this.highlight, this.radius);
  final Rect? target;
  final Color scrim;
  final Color highlight;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final background = Path()..addRect(Offset.zero & size);
    final rect = target;
    if (rect == null) {
      canvas.drawPath(background, Paint()..color = scrim);
      return;
    }
    final hole = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas
      ..drawPath(
          Path.combine(
              PathOperation.difference, background, Path()..addRRect(hole)),
          Paint()..color = scrim)
      ..drawRRect(
          hole,
          Paint()
            ..color = highlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_TutorialSpotlightPainter old) =>
      old.target != target ||
      old.scrim != scrim ||
      old.highlight != highlight ||
      old.radius != radius;
}
