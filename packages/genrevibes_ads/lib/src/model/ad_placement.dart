import 'ad_format.dart';

/// Logical application placement independent from a provider ad-unit ID.
final class AdPlacement {
  /// Creates an ad placement.
  const AdPlacement({required this.id, required this.format});

  /// Stable portfolio/application placement name, such as `download_complete`.
  final String id;

  /// Required creative format.
  final AdFormat format;

  @override
  bool operator ==(Object other) {
    return other is AdPlacement && other.id == id && other.format == format;
  }

  @override
  int get hashCode => Object.hash(id, format);
}
