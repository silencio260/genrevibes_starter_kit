/// Optional behaviors supported by a concrete IAP provider adapter.
final class IapCapabilities {
  /// Creates an IAP capability declaration.
  const IapCapabilities({
    required this.hostedPaywall,
    required this.customerCenter,
    required this.accountIdentification,
    required this.promotionalOffers,
  });

  /// Whether the provider can display its own paywall UI.
  final bool hostedPaywall;

  /// Whether the provider supplies customer-management UI.
  final bool customerCenter;

  /// Whether anonymous customers can be linked to application user IDs.
  final bool accountIdentification;

  /// Whether the adapter implements promotional offer flows.
  final bool promotionalOffers;
}
