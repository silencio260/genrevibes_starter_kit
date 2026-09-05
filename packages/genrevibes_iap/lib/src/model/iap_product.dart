/// Product categories normalized across IAP providers and app stores.
enum IapProductType {
  /// A product that can be consumed repeatedly.
  consumable,

  /// A durable, one-time purchase.
  nonConsumable,

  /// A recurring subscription.
  subscription,

  /// The provider did not expose a recognized type.
  unknown,
}

/// A purchasable product independent from any provider SDK model.
final class IapProduct {
  /// Creates a normalized product.
  const IapProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.price,
    required this.priceString,
    required this.currencyCode,
    this.offeringId,
    this.packageId,
    this.billingPeriodIso8601,
    this.metadata = const <String, Object?>{},
  });

  /// Store product identifier used when purchasing.
  final String id;

  /// Localized display title.
  final String title;

  /// Localized product description.
  final String description;

  /// Normalized product category.
  final IapProductType type;

  /// Numeric price in [currencyCode].
  final double price;

  /// Localized display price such as `$4.99`.
  final String priceString;

  /// ISO 4217 currency code when supplied by the store.
  final String currencyCode;

  /// Provider offering associated with this product.
  final String? offeringId;

  /// Provider package associated with this product.
  final String? packageId;

  /// ISO-8601 billing period, for example `P1M`.
  final String? billingPeriodIso8601;

  /// Additional non-essential provider fields.
  final Map<String, Object?> metadata;
}
