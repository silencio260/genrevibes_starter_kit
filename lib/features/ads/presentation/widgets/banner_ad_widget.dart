import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:genrevibes_starter_kit/starter_kit.dart';
import '../../domain/services/ad_suppression_manager.dart';
import '../../../iap/presentation/bloc/iap_bloc.dart';
import '../../../analytics/domain/entities/ad_revenue_event.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final String? adUnitId;
  final Color? backgroundColor;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.adUnitId,
    this.backgroundColor,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  String? _currentAdUnitId;

  @override
  void initState() {
    super.initState();
    AdSuppressionManager.instance.addListener(_onSuppressionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndLoad();
  }

  void _onSuppressionChanged() {
    if (mounted) setState(() {});
  }

  void _checkAndLoad() {
    final state = StarterKit.adsBloc.state;
    final adUnitId = widget.adUnitId ?? state.config?.bannerAdUnitId;

    if (adUnitId != null &&
        adUnitId.isNotEmpty &&
        adUnitId != _currentAdUnitId) {
      _currentAdUnitId = adUnitId;
      _loadAd(adUnitId);
    }
  }

  void _loadAd(String adUnitId) {
    _bannerAd?.dispose();
    _isLoaded = false;
    _bannerAd = null;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          StarterLog.e(
            'Banner Ad failed to load',
            tag: 'ADS',
            error: error.message,
            values: {'UnitID': adUnitId, 'Code': error.code},
          );
          ad.dispose();
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          StarterKit.sl<AdsRepository>().recordAdRevenue(
            AdRevenueEvent(
              value: valueMicros / 1000000.0,
              valueMicros: valueMicros,
              currency: currencyCode,
              adSource: 'AdMob',
              adUnitId: ad.adUnitId,
              adFormat: 'banner',
            ),
          );
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdSuppressionManager.instance.removeListener(_onSuppressionChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IapBloc, IapState>(
      bloc: StarterKit.iapBloc,
      builder: (context, iapState) {
        if (StarterKit.iapBloc.isPremium) {
          return const SizedBox.shrink();
        }

        return ListenableBuilder(
          listenable: AdSuppressionManager.instance,
          builder: (context, _) {
            if (AdSuppressionManager.instance.areAdsSuppressed) {
              return const SizedBox.shrink();
            }

            return BlocBuilder<AdsBloc, AdsState>(
              bloc: StarterKit.adsBloc,
              builder: (context, state) {
                final newAdUnitId =
                    widget.adUnitId ?? state.config?.bannerAdUnitId;
                if (newAdUnitId != null &&
                    newAdUnitId.isNotEmpty &&
                    newAdUnitId != _currentAdUnitId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _currentAdUnitId = newAdUnitId;
                      _loadAd(newAdUnitId);
                    }
                  });
                }

                if (_bannerAd == null || !_isLoaded) {
                  return const SizedBox.shrink();
                }

                return SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor ??
                          Theme.of(context).scaffoldBackgroundColor,
                    ),
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
