# genrevibes_onboarding

Onboarding completion state plus an optional presentation template. The
completion flag is the genuinely portfolio-reusable part; content, wording,
imagery, and navigation stay with the application.

`OnboardingController` reads and writes a single completion flag through
`genrevibes_storage`. Wrap the store in a `MigratingKeyValueStore` seeded with
`OnboardingKeys.legacyKeys`, or adopting this package re-onboards every existing
user on the release that ships it.

Unreadable state is treated as "not yet onboarded". Showing onboarding a second
time is a far better failure than never showing it to a genuinely new user.

`OnboardingView` is theme-driven and embeddable. It renders no `Scaffold` and no
`AppBar`, so a host can place it in its own route, a sheet, or a dialog, and it
takes colors from the ambient `ThemeData` rather than a hardcoded palette.

Artwork is supplied as a `WidgetBuilder` rather than an asset path. An app that
uses Lottie passes a Lottie widget, one that uses images passes an `Image`, and
neither pays for the other's dependency. This package depends on no animation or
image library at all.
