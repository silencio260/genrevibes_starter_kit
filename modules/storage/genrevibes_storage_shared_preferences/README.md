# genrevibes_storage_shared_preferences

SharedPreferences implementation of the `KeyValueStore` contract declared by
`genrevibes_storage`. An application installs this package only when a capability
it uses needs to remember something across launches.

Keeping the plugin here means the neutral storage contract, and every capability
built on it, stays free of a platform dependency. An app that prefers secure
storage, a database, or its own existing persistence layer implements the same
contract instead and never resolves SharedPreferences.

The plugin sits behind `PreferencesClient`, an injectable boundary, so tests
exercise this adapter without platform channels. Plugin faults are normalized to
`KitError` with a `shared_preferences_*` provider code and are never thrown.
