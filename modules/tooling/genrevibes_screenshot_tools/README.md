# GenRevibes screenshot tools

Development-only portfolio tooling for rendering real Flutter screens, composing
editable promotional images, and uploading localized Play Store copy and images.
Add this package to the **host's `dev_dependencies`**. Never import it from the
host's `lib/` or export it from the runtime starter-kit coordinator.

## Host integration

```yaml
dev_dependencies:
  genrevibes_screenshot_tools:
    path: packages/genrevibes_starter_kit/modules/tooling/genrevibes_screenshot_tools
```

Create a host-owned export entrypoint under `tool/promotions/`. The host registers
its real screen widgets, fixed demonstration state, locale delegates, fonts,
theme, image dimensions and filenames. Supply these through `ScreenshotProject`,
`ScreenshotScene`, `ScreenshotLocale` and `wrap`. `prepare`/`dispose` hooks install
and remove offline services. The kit does not import app BLoCs, bootstrap Firebase,
activate ads, or select a language catalogue.

```dart
void main() => registerScreenshotExports(ScreenshotProject(
  campaign: 'launch',
  locales: const [ScreenshotLocale(tag: 'en-US', locale: Locale('en', 'US'))],
  scenes: [ScreenshotScene(
    id: 'home',
    filename: '01-home.png',
    builder: (_) => const AppHomeScreen(), // host's actual widget
  )],
  wrap: (capture, child) => MaterialApp(
    locale: capture.locale.locale,
    supportedLocales: [capture.locale.locale],
    localizationsDelegates: appDelegates,
    theme: appTheme,
    home: child,
  ),
));
```

The example's `AppHomeScreen`, `appDelegates` and `appTheme` are host values.
Lunaris provides a full eight-screen implementation in `tool/promotions/`.
Use explicit prepare/dispose hooks to isolate state for every scene and locale.
Make actions fail instead of calling production services. Only expose locales
whose strings, scripts, framework delegates and fonts are ready in that host.

## Export

From the host app root, after `flutter pub get`:

```sh
flutter test tool/promotions/render.dart --dart-define=SCREENSHOT_LOCALES=en-US
```

This uses Flutter's headless runner; no device or emulator is required. It is an
image-export job, with no golden baseline files. Repository rules governing
`flutter test` still apply: implementation alone does not authorize running it.

Optional defines:

| Define | Meaning |
| --- | --- |
| `SCREENSHOT_LOCALES=en-US,fr-FR` | Exact registered app locale tags; unready/unknown tags fail |
| `SCREENSHOT_SCENES=home,feature` | Registered scene IDs; omitted means all scenes |
| `SCREENSHOT_REPLACE=true` | Explicit replacement of existing final PNGs |

Default output is `app_screenshots/<campaign>/<locale>/<filename>.png`. Phone
screenshots and feature graphics share that locale folder. The entire output
root must be Git-ignored and untracked; the exporter checks this before writing.
Supply `ScreenshotLocale.directoryName` to use an app-chosen delivery name such
as `US_English`, `LATAM_Spanish` or `Global_Arabic` in place of the locale tag.
These names must be simple path components and unique without regard to case.
The `tag` and Flutter `locale` still determine the rendered language, and
`SCREENSHOT_LOCALES` continues to filter the canonical tags, not folder names.
The host can place explicitly requested listing JSON alongside these final
images; the renderer publishes PNG files only and does not create metadata.
For a host outside Git, `requireIgnoredOutput: false` is an explicit host choice.
Output path components, case-insensitive filename collisions, symlinks, existing
files and final dimensions are checked. Rendering errors, including overflowing
layouts, fail the job. Bounded frames avoid waiting forever for ticking clocks.

Images are staged outside the project; all images must render before any final
file is published. A failed publish can leave an already-published subset; fix
the filesystem failure and rerun with the explicit replacement flag. Staging is
removed on normal success/failure. No manifests, ZIPs, contact sheets, prompts,
or hidden archives are put in the image delivery directory.

## Editable text and AI artwork

`PromotionLayout` combines `PromotionCopy` (editable headline/caption), brand,
`PromotionStyle`, and a real localized app-screen widget. `PromotionPhone` keeps
the app viewport independent of the promotional canvas. `featureGraphic: true`
uses a landscape composition. Phone and feature sizes are configurable; bundled
defaults are 1080×1920 and 1024×500.

Apps can use these building blocks or supply their own Flutter composition.
Keep all translatable text in widgets and app-owned translation resources,
including small badges and footnotes. `EditablePromotionText` fits text within
defined readable limits and fails rather than adding an ellipsis. Fonts need
glyphs for every selected script. `loadBundledScreenshotFonts` loads the host
font manifest and Material icon font; provider-fetched fonts need host preparation.

Image generation supplies **text-free** backgrounds, illustrations or decorative
assets through `PromotionStyle.backgroundArt`. Retain one reusable source asset
in the app's source/tooling area. Do not bake screen labels, marketing copy or
localizable numbers into that art. Translate existing flattened designs by first
reconstructing their editable layout; the exporter does not erase existing text.
AI screen refinements become production Flutter widgets before they are presented
as the app's actual UI. Design explorations remain explicitly labelled concepts.

Native WebViews, ads, system dialogs and other platform views need a separate
capture path when they are part of the requested content. Headless exports do
not establish device fidelity. Validate representative fonts, RTL, long copy,
images and layouts before generating a large campaign.

## Photographic masters with editable text planes

`LayeredPromotionTemplate` keeps a supplied image master intact and places
`PromotionTextLayer` regions over it. Each region has an app-owned string ID,
design-pixel rectangle, font limits, color/weight, line count and alignment.
An optional `quad` maps the text plane onto photographed phone-screen or glass
card corners using a projective homography. RTL changes glyph layout inside the
plane; it does not mirror the phone, artwork or quadrilateral. Optional gradient
colors reproduce a headline's top-to-bottom material treatment.

This is a different composition path from the generic `PromotionLayout`. It does
not draw a replacement phone or choose another background. The host prepares a
faithful master once, with every replaceable word removed, and registers every
localizable region, including small screen text and enlarged cards. Proper brand
names and invariant artwork can remain in the master. Existing flattened text is
not automatically erased by this widget.

OCR boxes describe visible **glyph ink**, not Flutter line boxes. For these
boxes, use `prepareLayeredPromotionText` after fonts are loaded, in the renderer's
real asynchronous `prepare` hook. It shapes/rasterizes each translated string,
finds its actual alpha bounds, and fits that cropped ink proportionally into the
registered panel. This avoids making the headline smaller just to fit invisible
font ascent/descent padding. No image-generation request occurs per language.

```dart
final layers = <PromotionTextLayer>[
  PromotionTextLayer(
    id: 'headline',
    rect: const Rect.fromLTWH(72, 48, 936, 140),
    maxFontSize: 180,
    minFontSize: 90,
    weight: FontWeight.w800,
  ),
  PromotionTextLayer(
    id: 'screenAction',
    rect: const Rect.fromLTWH(0, 0, 350, 38),
    quad: const [
      Offset(250, 1200), Offset(650, 1160),
      Offset(654, 1204), Offset(254, 1244),
    ],
    maxFontSize: 46,
    minFontSize: 24,
    alignment: TextAlign.center,
  ),
];
// Host values: copy, locale, selectedDirection, typography, fallbackFonts, master.
final prepared = await prepareLayeredPromotionText(
  layers: layers,
  strings: copy,
  typography: typography,
  fontFamilyFallback: fallbackFonts,
  locale: locale,
  direction: selectedDirection,
);
final composition = LayeredPromotionTemplate(
  artwork: master,
  designSize: const Size(1080, 1920),
  layers: layers,
  strings: copy,
  typography: typography,
  fontFamilyFallback: fallbackFonts,
  locale: locale,
  prepared: prepared,
);
// In the host's dispose hook, after the last capture frame:
// prepared.dispose();
```

Reuse the same layer instances and string values between preparation and widget
construction; stale prepared data throws. `prepared.effectiveFontSizes` exposes
the fitted local-plane sizes for review. The panel's width/height describe its
unprojected design-pixel scale, so choose them consistently with the photographed
plane; a deliberately smaller target quad also makes the resulting text smaller.
Prepared image resources belong to the host and must be disposed after export.

For a button, register the actual safe text area within its physical boundaries,
including the intended padding around any embedded icon. Set
`alignment: TextAlign.center` and
`verticalAlignment: PromotionTextVerticalAlignment.center` to center the fitted
glyph ink in that area. Vertical alignment defaults to `top` for existing OCR
layers; `bottom` is also supported. The prepared path uses actual alpha-ink
bounds, while the synchronous path aligns its normal text line box.
`prepared.localInkBounds` reports the resulting panel-local rectangles before
projection, so the host can check equal padding and centering rather than only
whether words fit. Button geometry and icon spacing remain host-owned.

When rebuilding a button's entire foreground, supply `leadingIcon: Icons.bolt`,
`iconSize: 28` and `iconGap: 12` on its text layer. The prepared renderer measures actual icon ink, fits its longest side to
`iconSize`, reserves that visible width plus the gap before fitting text, then
aligns the complete visible icon/label group.
With centered horizontal/vertical alignment, both the group's outside padding
and the icon/text vertical centers remain balanced as the language changes.
RTL places the leading icon to the right and mirrors directional icon glyphs
when their `IconData.matchTextDirection` requests it. The host must cover/remove
the original embedded icon first to prevent duplicates. Icon groups deliberately
require prepared rendering; the synchronous text-only path fails clearly rather
than approximating their ink metrics. `prepared.localIconBounds` reports the
actual visible icon-ink bounds alongside `localInkBounds` for spacing checks.
An optional `artworkOverlay` widget draws host-owned vector restoration between
the master and the text, in design coordinates. It can restore small icons or
separate a preserved active-tab marker from translated label ink. Keep this
artwork invariant across languages; translated words belong in text layers.

For authored full line-layout boxes rather than OCR ink boxes, omitting
`prepared` uses synchronous line-metric fitting. Both paths fail with the locale
and layer ID if copy cannot fit its minimum size. Validate complex-script ink,
long translations and projected labels visually; fit checks alone do not establish
a faithful master, legible original design, linguistic review or real device UI.
Image-based concepts remain concepts and must not be reported as device captures.

## Google Play upload

The pure-Dart uploader handles **main listing** translations and phone screenshot /
feature-graphic images. It does not release a binary, translate text, manage
country-targeted custom listings, rewrite credentials, or select account permissions.
Run it with the Dart SDK bundled with the selected Flutter SDK; an older separate
system Dart can fail on the host app's dependency graph before the CLI starts.
App locale tags and supported Play language slots must be mapped explicitly.
Two app locales targeting the same Play slot in one plan fail, preventing silent
overwrites. Reuse one suitable campaign per slot; country-specific marketing
requires a separate supported custom-listing workflow.

Keep the source plan outside image delivery folders. Paths are relative to the
plan file. A minimal schema is:

```json
{
  "packageName": "com.example.app",
  "listings": [{
    "appLocale": "en-US",
    "playLocale": "en-US",
    "directory": "../../app_screenshots/launch/en-US",
    "copyFile": "../../store_listing/en.json",
    "screenshots": ["01-home.png", "02-progress.png"],
    "featureGraphic": "google-play-feature-graphic-1024x500.png"
  }]
}
```

`copyFile` is an object with `title`, `shortDescription`, and `fullDescription`;
extra source fields such as screenshot headlines or review status are ignored.
Alternatively use a `copy` object with these three keys inline. Review text and
image content before choosing to upload; local checks do not establish linguistic
approval, ASO performance or Google policy compliance.

```sh
# Local checks only: no authentication or remote writes.
dart run genrevibes_screenshot_tools:play_store --plan tool/promotions/upload-plan.json

# Explicit remote check: creates an edit, uploads, validates, then discards it.
dart run genrevibes_screenshot_tools:play_store --plan tool/promotions/upload-plan.json --remote-check

# Explicit upload: commit changes without submitting them for review.
dart run genrevibes_screenshot_tools:play_store --plan tool/promotions/upload-plan.json --apply

# Explicit upload plus submission for review.
dart run genrevibes_screenshot_tools:play_store --plan tool/promotions/upload-plan.json --apply --submit-for-review
```

Remote commands use Google Application Default Credentials, e.g. an external
`GOOGLE_APPLICATION_CREDENTIALS` file, with the Android Publisher scope and
appropriate app-specific Play Console permissions. Never put credentials in the
plan, output folder or Git. The app must already exist in Play Console.

The uploader snapshots files before creating an edit. It replaces only the
provided locales' phone screenshot lists and, when supplied, feature graphic;
other image categories and languages remain untouched. Screenshot order is the
explicit filename-list order. It updates the three localized text fields,
validates, and either discards or commits one edit. It does not automatically
retry mutation/commit failures. Check Publishing overview before retrying an
uncertain commit. Avoid concurrent console edits during a remote operation.

Local checks cover required copy/lengths, duplicate mappings, 2–8 phone screenshots,
PNG readability, RGB opacity and image dimensions. Remote validation is still
required to establish that the account/app accepts a particular listing locale.
Google review, managed publishing and account state determine availability;
a successful upload is not a guarantee of immediate publication.

API references: [edits](https://developers.google.com/android-publisher/edits),
[image upload](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.images/upload),
[commit](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit).
