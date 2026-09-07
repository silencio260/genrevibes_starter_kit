# Changelog

## 0.1.0-dev.2

- Add `getStringList` and `setStringList` to `KeyValueStore`, implemented by the
  memory store and adopted by `MigratingKeyValueStore`, so list-valued legacy
  keys such as retention history can be migrated.

## 0.1.0-dev.1

- Add the provider-neutral `KeyValueStore` contract and `MemoryKeyValueStore`.
- Add `MigratingKeyValueStore` for adopting keys written by legacy app code.
