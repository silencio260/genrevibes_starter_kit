# genrevibes_starter_kit

Thin, instance-based lifecycle coordinator for modules selected by a host app.
It depends only on `genrevibes_core`: it does not resolve RevenueCat, AdMob,
Firebase, OneSignal, analytics SDKs, local notifications, GetIt, or BLoC.

Applications provide lazy `StarterModuleRegistration` factories in dependency
order. Disabled factories are never invoked. Optional module failures degrade
overall health while healthy modules continue; required failures are returned
after independent modules have had a chance to initialize. Concurrent startup
calls coalesce and disposal runs in reverse order.

The application remains the composition root and may keep its existing DI
container. `GenreVibesStarterKit.module<T>()` is only an instance lookup for
already-created modules, not a global service locator.
