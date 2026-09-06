# genrevibes_permissions_handler

permission_handler implementation of the `PermissionProvider` contract declared
by `genrevibes_permissions`, plus a `device_info_plus`-backed source for the
platform facts the media policy needs.

Neutral kinds map to plugin permissions in one place, and every plugin status
maps to a neutral state, so the coordinator and the application never see a
plugin type. Platform facts are loaded once at startup; if they cannot be read
the provider still starts and the policy falls back to the legacy single
storage permission rather than refusing to ask at all.

The plugin sits behind `PermissionHandlerClient`, an injectable boundary, so the
adapter is tested without an activity. Faults are normalized to `KitError` with
a `permission_handler_*` provider code.

Version range `>=11.3.1 <12.0.0`: 11.3.x runs on the family's Flutter 3.19
floor; 11.4.0 requires 3.24 and resolves only where the host allows it.
