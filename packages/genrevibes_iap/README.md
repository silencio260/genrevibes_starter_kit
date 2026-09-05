# genrevibes_iap

Provider-neutral in-app purchase models, contracts, and entitlement policies.

This package does not depend on RevenueCat, Adapty, StoreKit, or Google Play
Billing. Applications install a separate adapter package and supply its
`IapProvider` implementation during composition.

The API is experimental until the first stable release.

