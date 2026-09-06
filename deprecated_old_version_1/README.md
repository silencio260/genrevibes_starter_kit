# deprecated_old_version_1

The pre-modular GenRevibes starter kit: one Flutter plugin bundling every vendor
SDK, GetIt and BLoC, with a static `StarterKit` facade.

It is kept as a **read-only behavior reference** for the migration of portfolio
apps onto the modular package family in `../packages/`. It is not a dependency of
anything. `tool/verify_package_boundaries.sh` fails if any package or example
imports it.

The package name was changed to `genrevibes_starter_kit_legacy` so it can never
collide with `packages/genrevibes_starter_kit`.
