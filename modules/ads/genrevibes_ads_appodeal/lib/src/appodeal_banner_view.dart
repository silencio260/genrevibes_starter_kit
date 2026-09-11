import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import 'appodeal_ad_provider.dart';

/// Inline 320×50 Appodeal banner for a logical banner placement.
///
/// Renders nothing unless [enabled] and [provider] serves inventory for
/// [placement] right now — so not before initialization, and not after a
/// test-mode change that waits for a relaunch. It follows the provider's health
/// and appears or disappears as that changes.
///
/// Eligibility the provider cannot know — a premium user, an active
/// suppression, a hidden route — belongs to the application, passed as
/// [enabled].
///
/// Banner callbacks and revenue arrive on [AppodealAdProvider.events], not
/// here: Appodeal reports them once for the whole app, not per view.
final class AppodealBannerView extends StatelessWidget {
  /// Creates a banner view.
  const AppodealBannerView({
    super.key,
    required this.provider,
    required this.placement,
    required this.enabled,
  });

  /// The provider that initialized the SDK.
  final AppodealAdProvider provider;

  /// A banner placement configured on [provider].
  final AdPlacement placement;

  /// Application-owned display eligibility.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return StreamBuilder<ModuleHealth>(
      stream: provider.healthChanges,
      initialData: provider.health,
      builder: (context, _) {
        final name = provider.placementNameFor(placement);
        if (name == null || !provider.canShowInline(placement)) {
          return const SizedBox.shrink();
        }
        return AppodealBanner(
          adSize: AppodealBannerSize.BANNER,
          placement: name,
        );
      },
    );
  }
}
