# genrevibes_settings

Reusable settings models and embeddable settings presentation. This package
supplies the rows and the layout; what appears in them, and what those rows do,
stays with the application.

`SettingsItem` is a sealed hierarchy rather than one configurable class, so a row
cannot be built in a contradictory state such as a toggle that also navigates.
Actions, toggles, read-only values, and caller-supplied content are separate
types, and each reports whether it is interactive.

`SettingsList` renders no `Scaffold` and no `AppBar`. A widget that insists on
owning the whole screen cannot be reused by an app whose settings sit inside a
tab, a sheet, or a larger page, so this one is embeddable and takes all colors
from the ambient `ThemeData`.

`SettingsTile` is exported separately so a host can compose its own layout from
the same rows without adopting the list.

Only navigational rows show a chevron. Putting one on every row promises
navigation that a toggle or a read-only value does not deliver.
