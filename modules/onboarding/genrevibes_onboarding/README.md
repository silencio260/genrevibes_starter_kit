# genrevibes_onboarding

Introductory onboarding and reusable in-app tutorials. The package owns saved
progress, presentation, spotlight targeting and controls; product content,
wording, imagery, routes and successful-action rules stay with the application.

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

## OnboardingFlow

`OnboardingFlow` is the configurable flow, for apps that need more than
`OnboardingView`:

- **Every page a whole screen.** By default each page is a complete screen:
  its content, its own controls and, when it has one, its own ad, swiping in
  as a unit. A page without an ad is a different screen, laid out for the full
  screen, not an ad screen with its ad removed. With
  `layout: OnboardingScreenLayout.edgeToEdge` the artwork runs across the top
  edge to edge and takes the height the rest leaves: the top half on an ad
  screen, most of the screen without one, and `artworkFadeHeight` fades it
  into the page above the title. `immersive` puts the text and controls over
  full-bleed artwork instead.
  `OnboardingPresentation.sharedControls` keeps one set of controls and one ad
  area under the swiping content instead.
- **Any number of pages.** Each page can hide the ad with `showAd: false`.
- **An optional ad slot.** `OnboardingAdSlot` takes a builder, so onboarding
  stays ad-agnostic: pass `AppodealNativeAdView` from
  `genrevibes_ads_appodeal_native`, or anything else. It sits below or above the
  controls. Alternate `showAd` to put an ad screen between full-screen ones.
  Set `reservedHeight` to the ad's height so every ad screen is laid out with
  the ad's space from its first frame, and nothing moves when the ad loads.
- **Finish and skip actions.** A list of `OnboardingAction`s run in order, each
  awaited: `markCompleted`, `navigate`, `when` for a conditional step, or any
  async function, such as opening a paywall. A failing action stops the
  sequence unless `continueOnError`; each can have a `timeout`.
- **Layout.** `OnboardingControlsLayout.row` (skip, dots, next),
  `stacked` (dots over a centered next, leaving the bottom for an ad) or
  `fullWidthButton`, per flow or per page; `OnboardingFlowStyle` for colors,
  text styles, padding and transitions; `pageBuilder` and `controlsBuilder` to
  replace either, and `screenBuilder` (flow or page) to arrange a whole screen
  from its content, controls and ad.

```dart
OnboardingFlow(
  pages: const <OnboardingPage>[/* as many as the app needs */],
  controlsLayout: OnboardingControlsLayout.stacked,
  adSlot: OnboardingAdSlot(
    builder: (context, page) => AppodealNativeAdView(
      provider: ads,
      placement: AppPlacements.onboardingNative,
      enabled: adsAllowed,
    ),
  ),
  finishActions: <OnboardingAction>[
    OnboardingAction(openPaywall, continueOnError: true,
        timeout: const Duration(seconds: 30)),
    OnboardingAction.markCompleted(onboardingController),
    OnboardingAction.navigate(Routes.home),
  ],
);
```

## Folder connection preview

`FolderAccessPreview` is a local, labeled two-step visual for Android folder
access: Use this folder, then Allow. Labels and the folder name are configurable.
It respects reduced motion and does not replace the system picker. Apps own
folder validation, persisted grants, cancellation recovery and analytics.


## In-app tutorials

Use `TutorialController` and `TutorialOverlay` for coach marks, interactive
feature guides, editor tours, checkout help or any other app tutorial. They are
independent of `OnboardingController`: an app can have one introductory onboarding
and several tutorials, each with its own saved progress and completion.

| Shared API | Purpose |
|---|---|
| `TutorialController` | Initialize, start/resume, Next, Back, jump, complete, skip, stop, pause and replay one tutorial. |
| `TutorialProgress` / `TutorialOutcome` | Atomic saved step ID and `inProgress`, `completed` or `skipped` outcome. |
| `TutorialProgressStore` | Provider-neutral read/write contract returning `KitResult`. |
| `KeyValueTutorialProgressStore` | JSON snapshots over an existing `KeyValueStore`, with optional per-tutorial legacy-key migration. |
| `MemoryTutorialProgressStore` | Isolated preview/demo state; no persistent writes. |
| `TutorialStep` / `TutorialLabels` | App-supplied instructions, targets, actions and translated controls. |
| `TutorialTarget` | Highlight a keyed widget or supply overlay-local bounds from a resolver. |
| `TutorialOverlay` | Shared spotlight, touch policy, safe card placement, scrollable content and busy controls. |

### Create and own a controller

```dart
import 'package:genrevibes_onboarding/genrevibes_onboarding.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

TutorialController createEditorGuide(KeyValueStore appStore) {
  return TutorialController(
    tutorialId: 'editor_basics',
    stepIds: const ['add', 'export', 'ready'],
    store: KeyValueTutorialProgressStore(store: appStore),
  );
}
```

The app chooses a storage adapter in its own bootstrap; this package does not
import SharedPreferences, a router, analytics, ads or an app service locator.
Give each tutorial a stable nonempty ID and unique nonempty step IDs. IDs are
storage identities, not translated labels. A store can serve multiple tutorial
IDs; one owner/controller should write each ID at a time. The default snapshot
key is `genrevibes.tutorial.<tutorialId>.progress.v1`. `namespace` is configurable.
The JSON schema version describes the storage format, not a product rollout;
use a new tutorial ID when a redesigned guide should intentionally run again.

Await `initialize()` and inspect its `KitResult` before `start()`. Initialize reads
without presenting UI. Start resumes unfinished state; completed/skipped guides
stay inactive until explicit `replay()`. A failed read leaves initialization
retryable. A failed start write leaves the guide inactive. Show app-localized
recovery UI rather than converting failures into successful completion.

This is a `ChangeNotifier`, not a `StarterModule`. Its runtime or screen owner
calls `dispose()`; a borrowing screen removes its own listeners and can `stop()`
the session, without disposing a shared controller. Pending operations cannot
notify a disposed controller, and stopping during a pending start does not
reactivate it when the write finishes.

### Supply steps and actual actions

Place `TutorialOverlay` last in a bounded `Stack` above the content it explains.
Its step IDs and order must exactly match `controller.stepIds`; text/actions may
rebuild for locale changes or contextual recovery instructions. See the complete
[editor and search example](example/tutorial_example.dart) for working widget,
controller ownership, replay, keyboard input and route-return integration.
Embed `TutorialExample` in a `MaterialApp`; it uses memory unless a store is
injected, and its two guides keep independent progress.

For each `TutorialStep`:

- Pass localized `title`, `body` and optional `primaryLabel`; supply localized
  `TutorialLabels(next, previous, skip, finish)` at the screen boundary.
- Set `target: TutorialTarget.key(widgetKey)` to highlight a real control, or
  use `TutorialTarget.resolver` returning bounds relative to the overlay.
- Choose `TutorialInteraction.blocked` for explanation only, `targetOnly` to
  allow touches through the highlighted target, or `anywhere` for real swipes,
  text entry and canvas interaction. The card remains interactive in all modes.
- Omit `onPrimary` for shared Next/Finish. With a custom action, the app owns
  advancement: wait for the real action's result or a route return and call
  `controller.advanceFrom('expected_step')`. Target taps and card actions should
  call the same app operation. `showNext: true` offers an additional way onward.
- Use `TutorialCardPlacement.automatic`, `top`, `bottom` or `center`.
  Automatic placement uses the half opposite a target. Content scrolls within
  safe bounds and controls wrap; the keyboard reduces available card space.
  Tight layouts may overlap the target to preserve accessible escape controls.
- `decorationBuilder` supplies app-specific gesture hints or artwork; it cannot
  intercept touches or add screen-reader instructions. Respect reduced motion
  in custom animations. `cardBuilder` replaces the card content while retaining
  the shared controls, geometry and interaction layer.

Targets are measured after layout and on existing animation/scroll frames,
without forcing idle frames. Missing, detached or offscreen targets have no
spotlight hole, while card controls remain available. The app must scroll or
navigate to a required target, or show recovery text under the same step ID.
The kit never opens app routes, launches external apps, asks permissions or
assumes what counts as success.

`onFinish` and `onSkip` override the overlay's default controller completion.
If supplied, perform required app navigation/work, then explicitly call
`complete()` or `skip()`. Returning from these callbacks alone does not end the
tutorial. Route callback exceptions go to `onError`. Handle returned storage
failures or observe `controller.lastError`, displaying localized product copy
rather than diagnostic error messages.

### Persistence, pause and recovery

Step transitions and completion write one snapshot before changing the visible
step/outcome. Failed writes retain the previous state for retry. `isBusy` and
shared controls prevent overlapping writes and repeated taps. `advanceFrom(id)`
ignores stale, inactive or busy events; reconcile app state when idle if an event
that arrived during a save still requires advancement.

`previous()` returns to the previous saved step. `goTo(id)` jumps to a valid ID.
Reordering a tutorial resumes the same ID; removing its unfinished current step
falls back to the first step. Completed/skipped guides remain completed even
when steps are removed. An unknown requested ID returns a configuration error.

`pause()` hides the overlay while keeping `active.value` true; `resume()` restores
it. `enabled: false` hides a particular overlay without changing controller state.
Use these while a drawer, pushed route or native surface owns UI. `stop()` ends
the visible session without completion, leaving the checkpoint resumable.
`reset()` saves an unfinished first step without activating it. `replay()` saves
the first step and starts it. Explicit reset/replay can recover corrupt progress
without a successful prior initialize. Both affect only their own tutorial.

Use the read-only `active` listenable for app-owned competing-prompt policy.
A host can defer ratings, ads and other tutorials during an active session,
including a pause. Policy is not hardcoded into this package. For several guides
on one screen, the app selects one visible controller and stops/pauses the other.

### Adopt existing progress

```dart
final progressStore = KeyValueTutorialProgressStore(
  store: appStore, // the app's existing KeyValueStore
  legacyKeys: const {
    'editor_basics': TutorialLegacyKeys(
      completedKey: 'old_editor_guide_done',
      stepKey: 'old_editor_guide_step',
      firstStepId: 'add',
    ),
  },
);
```

Migration reads only explicitly supplied historical keys and saves a snapshot
before reporting success. Legacy keys are retained for rollback. New snapshots
always take precedence. Reset saves an unfinished snapshot instead of deleting
it, preventing replay from accidentally adopting the old completion flag again.
The package contains no launcher-specific migration keys or instructions.

Validation should distinguish source analysis from real device behavior. Check
read/write failure recovery, independent IDs, legacy completion and step adoption,
rapid taps, stale action returns, pause/stop/disposal, missing targets, keyboard,
large text, small screens and RTL in the destination app. The example is source
usage, not evidence of a completed device walkthrough.
