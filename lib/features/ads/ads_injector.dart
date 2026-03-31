import 'package:get_it/get_it.dart';

import 'domain/repositories/ads_repository.dart';
import 'domain/usecases/show_interstitial_usecase.dart';
import 'domain/usecases/show_rewarded_usecase.dart';
import 'domain/usecases/show_app_open_usecase.dart';
import 'presentation/bloc/ads_bloc.dart';

import '../analytics/domain/entities/ad_revenue_event.dart';

/// Initialize Ads feature dependencies
void initAdsFeature(
  GetIt sl, {
  AdsRepository? adsRepository,
  void Function(AdRevenueEvent)? onPaidEvent,
}) {
  // Repository
  if (adsRepository != null) {
    sl.registerLazySingleton<AdsRepository>(() => adsRepository);
  }

  // Use cases
  if (!sl.isRegistered<ShowInterstitialUseCase>()) {
    sl.registerLazySingleton<ShowInterstitialUseCase>(
      () => ShowInterstitialUseCase(repository: sl()),
    );
  }
  if (!sl.isRegistered<ShowRewardedUseCase>()) {
    sl.registerLazySingleton<ShowRewardedUseCase>(
      () => ShowRewardedUseCase(repository: sl()),
    );
  }
  if (!sl.isRegistered<ShowAppOpenUseCase>()) {
    sl.registerLazySingleton<ShowAppOpenUseCase>(
      () => ShowAppOpenUseCase(repository: sl()),
    );
  }

  // Bloc
  if (!sl.isRegistered<AdsBloc>()) {
    sl.registerLazySingleton<AdsBloc>(
      () => AdsBloc(
        adsRepository: sl(),
        showInterstitialUseCase: sl(),
        showRewardedUseCase: sl(),
        showAppOpenUseCase: sl(),
        onPaidEvent: onPaidEvent,
      ),
    );
  }
}
