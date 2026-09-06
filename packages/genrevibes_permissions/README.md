# genrevibes_permissions

Provider-neutral runtime permissions: which to ask for, how to ask, how often,
and how to explain why. It imports no permission plugin.

`PermissionKind` names capabilities, not platform permissions, so one request
works on Android 13's split media grants and on the older single storage grant.
`MediaPermissionPolicy` makes that choice from `PlatformFacts`, a value object
rather than `dart:io` calls, so every Android level is testable from one file.

`PermissionCoordinator` runs check → request → re-check. It never re-prompts a
permission that is already usable, reports `needsSettings` instead of prompting
a permanent denial, and applies `PermissionRequestThrottle` so a prompt the user
has dismissed repeatedly stops being a nag. Request counts and times persist
through `genrevibes_storage`.

`PermissionRationaleView` is the pre-prompt explanation screen: theme-driven,
embeddable, no `Scaffold`. The host supplies the copy, because wording is the
one part of a permission flow that must be specific to the feature asking.

Platform-specific access such as a scoped-storage folder picker stays with the
application; this package covers the permissions every app in the portfolio
asks for.
