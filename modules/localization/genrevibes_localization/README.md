# GenRevibes localization

Apps supply the language catalogue, translated resources, fonts, country names,
label configurations and profile synchronization. This package owns locale
matching, independent country selection, preference persistence and picker UI.
It contains no fixed portfolio catalogue or product text.

Use `LocalizationConfiguration` with canonical BCP 47 `LocaleOption` entries,
`CountryOption` entries, an app-specific storage key, a default locale and the
registered intl formatting locales. `LocalizationController` stores explicit
manual/device choices through `KeyValueStore`. Country changes preserve the
selected language and script. `LocaleTag` preserves Chinese and Punjabi script
identity and handles legacy language/region aliases.

`showLocalizationPicker` takes app-localized `LocalizationPickerLabels` and
`LocalizationPickerItem` values. A cancelled dialog differs from selecting the
device default. Account/profile delivery remains the host's responsibility.

`showLocalizationPickerPage` opens a full-screen route with rounded, searchable
rows and a centered header. It holds a draft selection until the top-right
checkmark is pressed; Back cancels without returning a choice. Supply a localized
`confirmLabel`, an optional translated `description`, and optional item `leading`
widgets and `titleDirection` values. The page uses the host's current theme and
supports device defaults independently of cancellation. The dialog API remains
available for compact pickers.

For a fixed layout across languages, pass `layoutDirection` to the page. This
controls row order, label alignment, search-icon placement and navigation actions;
localized page labels and search input retain the surrounding reading direction.
Item `titleDirection` and `subtitleDirection` control their text independently.
For example, a left-to-right layout can keep Arabic names left-aligned while
preserving their right-to-left reading order.

`LocalizationPickerPage` can also be embedded as a startup step: supply
`onConfirmed` to handle the choice without popping a route. In this mode the
page omits its automatic Back button. Set `isSaving` during persistence to show
progress and disable repeated confirmation, searching and selection changes.
The host decides when a successful save advances to its next startup step.

## Languages missing from Flutter or intl

Register an app-owned `SupplementalLocalizations` instance with loaders keyed by
language or language-script tag. Each loader returns `SupplementalLocaleData`
containing all required Material/Cupertino labels, text direction and a registered
intl locale. Put its delegates before the standard Flutter delegates. It validates
dictionary coverage, preserves raw `$placeholder` templates, shares loading across
delegates and uses intl formatting and plural selection. Its typed interface was
checked against Flutter 3.44.1; inspect it when upgrading Flutter's label API.

`registerCldrLocale` accepts app-bundled CLDR Gregorian/numeric maps, week data,
territory and currency. Call `initializeDateFormatting()` for built-in locales
first, then register supplemental locales before resolving formatting choices or
returning a supplemental bundle. Latin, Arabic and extended Arabic digits are
supported; unsupported numbering systems throw. The package does not fetch CLDR
or translations at runtime. Compact-number patterns are outside this API.

Keep framework dictionaries and CLDR/font licenses in the app. Validate raw label
placeholders against the source and obtain linguistic review for draft text;
complete keys alone do not establish translation quality. Render complex scripts
with bundled fonts and avoid tracking that breaks joining or mark placement.

## Dependencies and validation

This package uses Flutter, flutter_localizations, intl, genrevibes_core and
genrevibes_storage. Declare it in the host and resolve the kit dependencies using
that checkout's path overrides. The host supplies its generated localization
delegate alongside the shared supplemental delegates and Flutter delegates.
Static analysis and date/number sanity checks were run in Lunaris with Flutter
3.44.1 / intl 0.20.2. Device/build and fluent-speaker review are separate checks.
