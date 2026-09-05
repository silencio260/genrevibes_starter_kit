# GenreVibes Starter Kit architecture

Status: accepted for the `feature/modular-provider-architecture` branch.

## Objective

The starter kit is a family of independently versioned Flutter and Dart
packages. Applications install only the capabilities and provider adapters
they use. A provider that is absent from an application's `pubspec.yaml` must
not be downloaded, compiled, initialized, or added to a native build.

The existing single-package implementation remains in `lib/` as a reference
during the migration. New production APIs are developed under `packages/`.
Features move only after their behavior has been compared with the working
Story Saver implementation and covered by tests.

## Dependency direction

```text
application
  -> genrevibes_starter_kit (optional coordinator)
  -> selected provider adapters
       -> provider-neutral capability contracts
            -> genrevibes_core
```

Dependencies never point from core or a contract package toward a provider
adapter. Vendor SDK types must not appear in a contract package's public API.

## Package roles

- `genrevibes_core`: errors, results, module lifecycle, diagnostics, clocks,
  and logging contracts. It is a pure Dart package with no vendor SDKs.
- Capability packages such as `genrevibes_iap`: normalized domain models,
  provider contracts, capability declarations, and provider-independent
  policies.
- Provider adapters such as `genrevibes_iap_revenuecat`: vendor SDK imports,
  configuration, model mapping, error mapping, and native setup documentation.
- `genrevibes_starter_kit`: a thin, instance-based coordinator. It validates
  and starts the modules supplied by the application. It does not select or
  depend on concrete providers.
- UI packages: optional reusable presentation. Business contracts must remain
  usable without installing the UI package.

## Non-negotiable rules

1. A feature is explicitly enabled or disabled. Required features never fall
   back silently to a no-op provider.
2. Provider packages own all direct dependencies on their vendor SDK.
3. Public contracts use GenreVibes models rather than vendor models.
4. Configuration is passed through constructors or immutable configuration
   objects. Secrets are never committed or embedded in a published package.
5. The application owns dependency injection. The coordinator must not force
   GetIt, BLoC, Riverpod, or Provider on consumers.
6. Every adapter passes the contract tests for its capability.
7. Cross-feature policy is provider-neutral. Examples include premium ad
   suppression, consent gating, notification frequency, and analytics naming.
8. Initialization and disposal are observable through module health reports.
9. One provider failure must not silently corrupt another feature.
10. Published package constraints describe versions that CI actually tests.

## Provider selection

Provider selection is compile-time by default: an app adds one adapter package
and supplies its implementation during composition. Analytics is the primary
exception because sending an event to multiple independent sinks is a supported
use case.

Runtime switching is supported only when an application deliberately includes
multiple adapters. This is useful for a staged IAP migration, but it means both
native SDKs are present in that transitional release.

## Compatibility baseline

New pure-Dart contracts initially target Dart `>=3.3.0 <4.0.0`. We do not use
native Pub workspaces yet because workspace membership would raise the package
minimum to Dart 3.6. Each package remains independently resolvable.

Before the first public release, CI will establish the actual minimum Flutter
version for every Flutter adapter. A vendor SDK upgrade that raises the minimum
Flutter, Dart, Gradle, Android SDK, Kotlin, CocoaPods, Xcode, or iOS deployment
target requires a new adapter major version when existing consumers cannot
upgrade safely.

## Migration rule

The active Story Saver application and `deprecated_old_version_1` are behavior
references, not dependencies. New packages must never import from either tree.
Each feature migration has a parity checklist, a compatibility facade where
needed, and a separate removal commit for the replaced app implementation.

