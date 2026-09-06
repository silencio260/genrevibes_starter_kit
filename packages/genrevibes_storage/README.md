# genrevibes_storage

Provider-neutral key-value persistence for GenRevibes capability packages. It
declares a `KeyValueStore` contract and an in-memory implementation, and depends
on nothing but `genrevibes_core`. No storage plugin is forced on a consuming
application.

Capabilities that need to remember something across launches, such as app rating
eligibility or onboarding completion, depend on this contract rather than on
SharedPreferences directly. An application chooses the implementation, normally
`genrevibes_storage_shared_preferences`, and supplies it during composition.

A missing key is reported as a successful `null` rather than a failure, so a
first run is never mistaken for broken storage. Implementations never throw
across the boundary; every fault arrives as a normalized `KitError`.

`MigratingKeyValueStore` wraps any store and reads legacy key names written by a
pre-package implementation, copying the value forward on first read. Adopting a
capability therefore does not reset state a host application already persisted
under its own key names.
