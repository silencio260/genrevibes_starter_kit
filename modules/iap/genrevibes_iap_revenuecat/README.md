# genrevibes_iap_revenuecat

RevenueCat implementation of the provider-neutral `genrevibes_iap` contract.

The package depends on `purchases_flutter` 9.x. RevenueCat paywall and customer
center UI are injected through `RevenueCatUiPresenter`; the
`purchases_ui_flutter` dependency will live in a separate adapter so apps that
do not use RevenueCat UI do not compile it.

The API is experimental until the first stable release.

