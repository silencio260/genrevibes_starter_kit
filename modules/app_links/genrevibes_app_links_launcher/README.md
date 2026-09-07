# genrevibes_app_links_launcher

url_launcher and share_plus implementation of the `LinkOpener` contract
declared by `genrevibes_app_links`.

URLs open in an external application by default; `mailto` URIs are built with
subject and body as query parameters; sharing goes through the platform share
sheet. Both plugins sit behind `LauncherClient`, an injectable boundary, so the
adapter is tested without a device. Faults are normalized to `KitError` with a
`url_launcher_*` provider code.

`share_plus` is pinned to `>=10.1.3 <11.0.0`. 11.x replaced the static `Share`
API with `SharePlus.instance` and raised the Flutter floor to 3.22; moving
across that boundary is a deliberate adapter major, tracked in the risk
register.
