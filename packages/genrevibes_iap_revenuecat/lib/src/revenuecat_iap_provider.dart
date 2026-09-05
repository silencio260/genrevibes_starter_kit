import 'dart:async';

import 'package:flutter/services.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;

import 'revenuecat_configuration.dart';
import 'revenuecat_mapper.dart';
import 'revenuecat_ui_presenter.dart';

/// RevenueCat implementation of the provider-neutral [IapProvider] contract.
final class RevenueCatIapProvider implements IapProvider {
  /// Creates a RevenueCat provider.
  RevenueCatIapProvider({
    required RevenueCatConfiguration configuration,
    RevenueCatUiPresenter? uiPresenter,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _configuration = configuration,
        _uiPresenter = uiPresenter,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'iap',
          provider: 'revenuecat',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final RevenueCatConfiguration _configuration;
  final RevenueCatUiPresenter? _uiPresenter;
  final KitClock _clock;
  final KitLogger _logger;
  final Map<String, revenuecat.StoreProduct> _products =
      <String, revenuecat.StoreProduct>{};
  final StreamController<EntitlementSnapshot> _entitlementChanges =
      StreamController<EntitlementSnapshot>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();

  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;
  revenuecat.CustomerInfoUpdateListener? _customerInfoListener;

  @override
  IapCapabilities get capabilities => IapCapabilities(
        hostedPaywall: _uiPresenter != null,
        customerCenter: _uiPresenter != null,
        accountIdentification: true,
        promotionalOffers: false,
      );

  @override
  Stream<EntitlementSnapshot> get entitlementChanges =>
      _entitlementChanges.stream;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'iap';

  @override
  String get providerId => 'revenuecat';

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) {
      return _failure<void>(
        KitErrorCode.notInitialized,
        'RevenueCat provider has already been disposed.',
      );
    }

    final apiKey = _configuration.apiKeyForCurrentPlatform();
    if (apiKey == null) {
      return _failHealth<void>(
        KitErrorCode.invalidConfiguration,
        'No RevenueCat API key is configured for this platform.',
      );
    }

    _setHealth(ModuleState.initializing);
    try {
      await revenuecat.Purchases.setLogLevel(_mapLogLevel());
      if (!await revenuecat.Purchases.isConfigured) {
        final sdkConfiguration = revenuecat.PurchasesConfiguration(apiKey)
          ..appUserID = _configuration.initialAppUserId;
        await revenuecat.Purchases.configure(sdkConfiguration);
      }

      _customerInfoListener = _handleCustomerInfoUpdate;
      revenuecat.Purchases.addCustomerInfoUpdateListener(
        _customerInfoListener!,
      );
      final customerInfo = await revenuecat.Purchases.getCustomerInfo();
      _initialized = true;
      _emitCustomerInfo(customerInfo);
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _mapFailure<void>(error, stackTrace, updateHealth: true);
    }
  }

  @override
  Future<KitResult<List<IapProduct>>> getProducts({
    Set<String> productIds = const <String>{},
    String? placementId,
  }) async {
    final ready = _requireReady<List<IapProduct>>();
    if (ready != null) return ready;

    try {
      if (productIds.isNotEmpty) {
        final products = await revenuecat.Purchases.getProducts(
          productIds.toList(growable: false),
        );
        _cacheProducts(products);
        return KitSuccess<List<IapProduct>>(
          products.map(mapRevenueCatProduct).toList(growable: false),
        );
      }

      final offering = placementId == null
          ? (await revenuecat.Purchases.getOfferings()).current
          : await revenuecat.Purchases.getCurrentOfferingForPlacement(
              placementId,
            );
      if (offering == null) {
        return const KitSuccess<List<IapProduct>>(<IapProduct>[]);
      }

      for (final package in offering.availablePackages) {
        _products[package.storeProduct.identifier] = package.storeProduct;
      }
      return KitSuccess<List<IapProduct>>(
        offering.availablePackages
            .map(
              (package) => mapRevenueCatProduct(
                package.storeProduct,
                offeringId: offering.identifier,
                packageId: package.identifier,
              ),
            )
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _mapFailure<List<IapProduct>>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<PurchaseResult>> purchase(String productId) async {
    final ready = _requireReady<PurchaseResult>();
    if (ready != null) return ready;

    try {
      var product = _products[productId];
      if (product == null) {
        final products = await revenuecat.Purchases.getProducts(<String>[
          productId,
        ]);
        _cacheProducts(products);
        product = _products[productId];
      }
      if (product == null) {
        return _failure<PurchaseResult>(
          KitErrorCode.unavailable,
          'RevenueCat could not find product $productId.',
        );
      }

      final result = await revenuecat.Purchases.purchase(
        revenuecat.PurchaseParams.storeProduct(product),
      );
      final snapshot = _emitCustomerInfo(result.customerInfo);
      return KitSuccess<PurchaseResult>(
        PurchaseResult(
          status: PurchaseStatus.purchased,
          productId: productId,
          entitlements: snapshot,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      final code = revenuecat.PurchasesErrorHelper.getErrorCode(error);
      if (code == revenuecat.PurchasesErrorCode.purchaseCancelledError) {
        return const KitSuccess<PurchaseResult>(
          PurchaseResult(status: PurchaseStatus.cancelled),
        );
      }
      if (code == revenuecat.PurchasesErrorCode.paymentPendingError) {
        return KitSuccess<PurchaseResult>(
          PurchaseResult(status: PurchaseStatus.pending, productId: productId),
        );
      }
      return _mapFailure<PurchaseResult>(error, stackTrace);
    } on Object catch (error, stackTrace) {
      return _mapFailure<PurchaseResult>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<PurchaseResult>> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  }) async {
    final ready = _requireReady<PurchaseResult>();
    if (ready != null) return ready;
    final presenter = _uiPresenter;
    if (presenter == null) {
      return _failure<PurchaseResult>(
        KitErrorCode.unsupported,
        'RevenueCat UI is not installed for this application.',
      );
    }

    try {
      final status = await presenter.presentPaywall(
        placementId: placementId,
        requiredEntitlementId: requiredEntitlementId,
      );
      final snapshot = mapRevenueCatCustomerInfo(
        await revenuecat.Purchases.getCustomerInfo(),
      );
      _entitlementChanges.add(snapshot);
      return KitSuccess<PurchaseResult>(
        PurchaseResult(status: status, entitlements: snapshot),
      );
    } on Object catch (error, stackTrace) {
      return _mapFailure<PurchaseResult>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<void>> presentCustomerCenter() async {
    final ready = _requireReady<void>();
    if (ready != null) return ready;
    final presenter = _uiPresenter;
    if (presenter == null) {
      return _failure<void>(
        KitErrorCode.unsupported,
        'RevenueCat UI is not installed for this application.',
      );
    }

    try {
      await presenter.presentCustomerCenter();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return _mapFailure<void>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<EntitlementSnapshot>> restorePurchases() async {
    final ready = _requireReady<EntitlementSnapshot>();
    if (ready != null) return ready;
    try {
      final customerInfo = await revenuecat.Purchases.restorePurchases();
      return KitSuccess<EntitlementSnapshot>(_emitCustomerInfo(customerInfo));
    } on Object catch (error, stackTrace) {
      return _mapFailure<EntitlementSnapshot>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<EntitlementSnapshot>> getEntitlements({
    bool forceRefresh = false,
  }) async {
    final ready = _requireReady<EntitlementSnapshot>();
    if (ready != null) return ready;
    try {
      if (forceRefresh) {
        await revenuecat.Purchases.invalidateCustomerInfoCache();
      }
      final customerInfo = await revenuecat.Purchases.getCustomerInfo();
      return KitSuccess<EntitlementSnapshot>(_emitCustomerInfo(customerInfo));
    } on Object catch (error, stackTrace) {
      return _mapFailure<EntitlementSnapshot>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<EntitlementSnapshot>> identify(String appUserId) async {
    final ready = _requireReady<EntitlementSnapshot>();
    if (ready != null) return ready;
    if (appUserId.trim().isEmpty) {
      return _failure<EntitlementSnapshot>(
        KitErrorCode.invalidConfiguration,
        'The application user ID must not be empty.',
      );
    }
    try {
      final result = await revenuecat.Purchases.logIn(appUserId.trim());
      return KitSuccess<EntitlementSnapshot>(
        _emitCustomerInfo(result.customerInfo),
      );
    } on Object catch (error, stackTrace) {
      return _mapFailure<EntitlementSnapshot>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<EntitlementSnapshot>> resetIdentity() async {
    final ready = _requireReady<EntitlementSnapshot>();
    if (ready != null) return ready;
    try {
      final customerInfo = await revenuecat.Purchases.logOut();
      return KitSuccess<EntitlementSnapshot>(_emitCustomerInfo(customerInfo));
    } on Object catch (error, stackTrace) {
      return _mapFailure<EntitlementSnapshot>(error, stackTrace);
    }
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    final listener = _customerInfoListener;
    if (listener != null) {
      revenuecat.Purchases.removeCustomerInfoUpdateListener(listener);
    }
    _products.clear();
    _initialized = false;
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _entitlementChanges.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _handleCustomerInfoUpdate(revenuecat.CustomerInfo customerInfo) {
    _emitCustomerInfo(customerInfo);
  }

  EntitlementSnapshot _emitCustomerInfo(revenuecat.CustomerInfo customerInfo) {
    final snapshot = mapRevenueCatCustomerInfo(customerInfo);
    if (!_entitlementChanges.isClosed) _entitlementChanges.add(snapshot);
    return snapshot;
  }

  void _cacheProducts(Iterable<revenuecat.StoreProduct> products) {
    for (final product in products) {
      _products[product.identifier] = product;
    }
  }

  revenuecat.LogLevel _mapLogLevel() => switch (_configuration.logging) {
        RevenueCatLogging.errors => revenuecat.LogLevel.error,
        RevenueCatLogging.warnings => revenuecat.LogLevel.warn,
        RevenueCatLogging.info => revenuecat.LogLevel.info,
        RevenueCatLogging.debug => revenuecat.LogLevel.debug,
      };

  KitFailure<T>? _requireReady<T>() {
    if (_initialized && !_disposed) return null;
    return _failure<T>(
      KitErrorCode.notInitialized,
      'RevenueCat must be initialized before this operation.',
    );
  }

  KitFailure<T> _failure<T>(KitErrorCode code, String message) {
    return KitFailure<T>(KitError(code: code, message: message));
  }

  KitFailure<T> _failHealth<T>(KitErrorCode code, String message) {
    final failure = _failure<T>(code, message);
    _setHealth(ModuleState.failed, error: failure.error);
    return failure;
  }

  KitFailure<T> _mapFailure<T>(
    Object error,
    StackTrace stackTrace, {
    bool updateHealth = false,
  }) {
    final mapped = _mapError(error, stackTrace);
    _logger.log(
      KitLogLevel.error,
      mapped.message,
      moduleId: moduleId,
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'provider_code': mapped.providerCode},
    );
    if (updateHealth) _setHealth(ModuleState.failed, error: mapped);
    return KitFailure<T>(mapped);
  }

  KitError _mapError(Object error, StackTrace stackTrace) {
    if (error is PlatformException) {
      final providerCode = revenuecat.PurchasesErrorHelper.getErrorCode(error);
      final code = switch (providerCode) {
        revenuecat.PurchasesErrorCode.purchaseCancelledError =>
          KitErrorCode.cancelled,
        revenuecat.PurchasesErrorCode.networkError ||
        revenuecat.PurchasesErrorCode.offlineConnectionError ||
        revenuecat.PurchasesErrorCode.apiEndpointBlocked =>
          KitErrorCode.network,
        revenuecat.PurchasesErrorCode.configurationError ||
        revenuecat.PurchasesErrorCode.invalidCredentialsError ||
        revenuecat.PurchasesErrorCode.invalidAppUserIdError =>
          KitErrorCode.invalidConfiguration,
        revenuecat.PurchasesErrorCode.purchaseNotAllowedError ||
        revenuecat.PurchasesErrorCode.insufficientPermissionsError =>
          KitErrorCode.permissionDenied,
        revenuecat.PurchasesErrorCode.productRequestTimeout =>
          KitErrorCode.timeout,
        revenuecat.PurchasesErrorCode.unsupportedError =>
          KitErrorCode.unsupported,
        _ => KitErrorCode.provider,
      };
      return KitError(
        code: code,
        message: error.message ?? 'RevenueCat operation failed.',
        providerCode: providerCode.name,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return KitError(
      code: KitErrorCode.unknown,
      message: 'RevenueCat operation failed: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
