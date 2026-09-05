import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';
import 'package:genrevibes_iap_revenuecat_ui/genrevibes_iap_revenuecat_ui.dart';

void main() {
  runApp(const RevenueCatExampleApp());
}

/// Minimal composition example for RevenueCat IAP and optional hosted UI.
final class RevenueCatExampleApp extends StatefulWidget {
  /// Creates the example application.
  const RevenueCatExampleApp({super.key});

  @override
  State<RevenueCatExampleApp> createState() => _RevenueCatExampleAppState();
}

final class _RevenueCatExampleAppState extends State<RevenueCatExampleApp> {
  late final RevenueCatIapProvider _iap;
  StreamSubscription<Object?>? _entitlementSubscription;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _iap = RevenueCatIapProvider(
      configuration: const RevenueCatConfiguration(
        androidApiKey: String.fromEnvironment('REVENUECAT_ANDROID_API_KEY'),
        iosApiKey: String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
        logging: RevenueCatLogging.debug,
      ),
      uiPresenter: const RevenueCatUiAdapter(displayCloseButton: true),
    );
    _entitlementSubscription = _iap.entitlementChanges.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _status = snapshot.activeEntitlementIds.isEmpty
            ? 'No active entitlement'
            : 'Active: ${snapshot.activeEntitlementIds.join(', ')}';
      });
    });
  }

  @override
  void dispose() {
    unawaited(_entitlementSubscription?.cancel());
    unawaited(_iap.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    final result = await _iap.initialize();
    _showResult(
      result.fold(
        onSuccess: (_) => 'RevenueCat initialized',
        onFailure: (error) => 'Initialization failed: ${error.message}',
      ),
    );
  }

  Future<void> _showPaywall() async {
    final result = await _iap.presentPaywall(requiredEntitlementId: 'Pro');
    _showResult(
      result.fold(
        onSuccess: (purchase) => 'Paywall result: ${purchase.status.name}',
        onFailure: (error) => 'Paywall failed: ${error.message}',
      ),
    );
  }

  Future<void> _restore() async {
    final result = await _iap.restorePurchases();
    _showResult(
      result.fold(
        onSuccess: (snapshot) =>
            'Restored ${snapshot.activeEntitlementIds.length} entitlement(s)',
        onFailure: (error) => 'Restore failed: ${error.message}',
      ),
    );
  }

  void _showResult(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('GenreVibes RevenueCat example')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _initialize,
                  child: const Text('Initialize'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _showPaywall,
                  child: const Text('Show paywall'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _restore,
                  child: const Text('Restore purchases'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
