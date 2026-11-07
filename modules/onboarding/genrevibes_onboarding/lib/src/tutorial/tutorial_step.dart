import 'dart:async';
import 'package:flutter/widgets.dart';

/// What can receive touches behind the tutorial card.
enum TutorialInteraction { blocked, targetOnly, anywhere }

enum TutorialCardPlacement { automatic, top, bottom, center }

/// An app can provide a key or a custom resolver returning overlay-local bounds.
/// The target must share the overlay's render tree; missing/offscreen targets
/// resolve to null and leave the card controls usable.
final class TutorialTarget {
  const TutorialTarget.key(GlobalKey this.key, {this.padding = 6})
      : resolver = null;
  const TutorialTarget.resolver(Rect? Function(BuildContext context) resolve,
      {this.padding = 6})
      : resolver = resolve,
        key = null;
  final GlobalKey? key;
  final Rect? Function(BuildContext context)? resolver;
  final double padding;

  Rect? resolve(BuildContext context) {
    final custom = resolver;
    if (custom != null) return custom(context)?.inflate(padding);
    final target = key?.currentContext?.findRenderObject();
    final overlay = context.findRenderObject();
    if (target is! RenderBox ||
        overlay is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    // localToGlobal(ancestor:) requires an actual ancestor, not a sibling or
    // a target on another Navigator's overlay. Global coordinates support both.
    final points = [
      Offset.zero,
      Offset(target.size.width, 0),
      Offset(0, target.size.height),
      Offset(target.size.width, target.size.height)
    ]
        .map((point) => overlay.globalToLocal(target.localToGlobal(point)))
        .toList();
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final point in points.skip(1)) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    return bounds.inflate(padding);
  }
}

/// Product content and actions. No routes, SDKs or app names live in the kit.
final class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.body,
    this.target,
    this.interaction = TutorialInteraction.blocked,
    this.placement = TutorialCardPlacement.automatic,
    this.primaryLabel,
    this.onPrimary,
    this.showNext = false,
    this.allowSkip = true,
    this.decorationBuilder,
  });
  final String id;
  final String title;
  final String body;
  final TutorialTarget? target;
  final TutorialInteraction interaction;
  final TutorialCardPlacement placement;
  final String? primaryLabel;

  /// Null uses the controller's Next/Finish. A custom action owns advancement:
  /// report a real result/return event through controller.advanceFrom(stepId).
  final FutureOr<void> Function()? onPrimary;

  /// An extra Next button alongside a custom primary action.
  final bool showNext;
  final bool allowSkip;

  /// Decorative gesture hints/illustrations; excluded from touch and semantics.
  final WidgetBuilder? decorationBuilder;
}

/// Supply translated controls at the screen boundary.
final class TutorialLabels {
  const TutorialLabels(
      {required this.next,
      required this.previous,
      required this.skip,
      required this.finish});
  final String next;
  final String previous;
  final String skip;
  final String finish;
}
