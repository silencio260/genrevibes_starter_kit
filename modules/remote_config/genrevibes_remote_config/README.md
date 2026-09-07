# genrevibes_remote_config

Provider-neutral typed remote configuration. Applications define a schema of
typed keys and bundled defaults. The coordinator validates every cache/provider
value independently and retains the previous valid value when a refresh is
missing, malformed, out of range, or unavailable.

Cross-launch persistence is injected through `RemoteConfigCache`; the default
memory cache only lasts for the current process. Provider adapters may also
restore their own persisted activated values during initialization.
