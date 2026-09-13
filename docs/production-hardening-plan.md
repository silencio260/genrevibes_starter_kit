# Fix plan: starter kit and Story Saver

13 September 2026. Source changes implemented; device verification remains.

## What changed

- Startup now renders a loading/retry screen, bounds service waits and owns
  cleanup callbacks. Deferred consent starts after the app renders.
- Consent prompts only when the SDK says it is required. Failure or an
  eight-second timeout lets ad initialization continue. Consent status stays
  truthful; a timeout cannot dismiss a native form or guarantee an ad fill.
- Kit Lab shares the actual log recorder and includes notifications, rating and
  onboarding. Its module list includes disabled, waiting and failed services.
- Shared developer defaults remain available. Each app may override the passcode,
  restrict its actions or opt out. Listed phones still work. Lab pages recheck
  access, and simulated premium depends on current premium-simulation access.
- Story Saver uses its configured Pro entitlement and one shared snapshot.
  Pending/cancelled purchases and restore failures remain distinct. Purchase
  analytics no longer invent a price or currency.
- Replay shows requested/applied settings and stops on stricter pending masking.
  Feedback and passcode routes use the PostHog mask widget. Notification analytics
  omit message contents and arbitrary payloads.
- Feedback submission/picking is guarded and bounded. Failed submission retains
  the form. Unsupported FeedbackNest metadata returns an error.
- Home rechecks permissions on resume and consumes saved-media notification taps
  after routes are ready. The local scheduler supports timezone updates;
  persisted campaign definitions must still be refreshed by their owner.
- Package requirements and feature lists are corrected. The parent submodule
  mapping now matches the existing `agents` checkout; no agent files changed.
- See [portfolio adoption](portfolio-adoption.md) for setup and app-level choices.

## Verification status

Changed Dart sources were checked with the formatter and inspected against local
API declarations. Package paths, exports, dependency floors and Git whitespace
are checked locally. This is not a claim that compilation or device scenarios
passed. A subsequent `flutter analyze` run found two nullable-error type issues
in the coordinator; both are fixed. The outdated exclusion for the archived
starter kit was corrected without excluding active kit packages.

Latest analyzer result: **0 errors, 7 warnings, 331 informational notices**.
The command still exits with status 1 because warnings/lints remain. The seven
warnings are in existing saved-media/status code (unused declarations/imports
and redundant null checks). No tests or builds were run.

At the owner's request, `agents/AGENTS.md` now permits routine `flutter analyze`
without a separate request. Tests and builds remain opt-in; agent skills were
not revamped.

Before a release, verify consent required/not-required/error/slow cases, retry
and disposal with delayed providers, purchase/pending/cancel/restore, passcode
revocation, replay masking in an actual recording, feedback keyboard/large text
and timeout recovery, permission revocation and notification cold launch on a
phone. Also verify an upgraded install retains saved state and daily schedules
across timezone/DST changes. Story Saver's Android-only native ads must not be
presented as an iOS feature.

Device and store-provider checks remain outstanding. CI remains a small deferred TODO.

## Original work scope (with your corrections)

We will fix the kit and how Story Saver uses it, then document how another app
can use the same features. We will leave the agents/skills folder alone.
CI stays a small TODO for later.

Before each fix, check the current code: other work may already have fixed part
of the problem. Keep existing user data and the current screen designs.

## 1. Fix startup and cleanup

**Problem:** Some services can keep running after the app has tried to stop or
replace them. Retrying startup could then create duplicate listeners. Startup
errors are recorded, but the app does not always give the user a way to recover.

**Changes:**

- Give the app one place to stop its services and remove their listeners.
- Keep cleaning up if one service fails to stop. Ignore results that arrive
  after that service has been stopped.
- Show a loading screen while services start. If something essential fails,
  show an explanation and a Retry button.
- Let the app remain usable when an optional service, such as analytics, fails.
- Start applicable consent prompts after a screen is visible. Continue ad
  initialization on consent failure or after eight seconds; retain real consent
  signals and let the SDK decide available inventory.

**Done when:** Retry does not duplicate work, slow services cannot leave the app
stuck forever, and a failed optional service does not prevent use of the app.

## 2. Make Kit Lab show what is actually happening

**Problem:** The Lab's log recorder is not connected to the services producing
logs. Some features already used by the app are missing from the Lab.

**Changes:**

- Connect the logs so the Kit log page shows real activity.
- Connect local notifications, rating and onboarding, and add their missing
  controls where needed.
- Explain whether a feature is turned off, not connected, unsupported on this
  phone, or failing. Do not label all of these as “not adopted.”
- Explain which logs are available in a store build.
- Write a short guide for adding the Lab to another app.

**Done when:** The Lab shows the app's actual services, their errors and their logs.

## 3. Fix subscription checks and developer premium mode

**Problem:** The app currently treats any active entitlement—a purchase benefit—as
premium. That will be wrong in an app with separate purchases for removing ads
and unlocking other features. Purchase reporting also uses a placeholder price
of zero USD.

**Changes:**

- Configure which purchase unlocks each feature. Keep Story Saver's intended
  Pro behavior.
- Use one shared subscription status throughout the app.
- Show the difference between a successful purchase, cancellation, pending
  payment and failed restore.
- Report real purchase amounts when available. Otherwise report that a purchase
  happened without inventing a price or currency.
- Keep developer premium mode separate from a real subscription. Turn it off
  when developer access ends.

**Developer access:** Keep the kit's reusable defaults, including its fallback
passcode. Apps may override them, restrict passcode sessions to diagnostics,
disable passcodes or disable kit developer access. Keep registered developer
phones working. The shared controller implements these choices for every app.

**Done when:** The right purchases unlock the right features, restore errors are
visible, and developer premium mode cannot survive the loss of developer access.

## 4. Fix screen-recording controls and analytics

**Problem:** A setting can say screen text is hidden from recordings even though
the recording SDK will not apply that change until it restarts. Notification
tracking also sends the notification's full contents to analytics.

**Changes:**

- Show which recording settings are actually active and which need a restart.
- Stop recording if a newly requested privacy setting cannot be applied yet.
- Keep feedback messages, screenshots and developer passcode entry out of
  recordings.
- Send only the notification details needed for tracking, rather than its full
  message and extra data.
- Make recording choices explicit when another app adopts the kit. Keep Story
  Saver's existing recording-volume choice unless we deliberately change it.

**Done when:** Recording controls do what the Lab says, and private form/passcode
contents are absent from recordings we check.

## 5. Make forms, permissions and notifications handle failures properly

**Forms:** A failed or slow submission should keep the user's text, stop the
loading indicator and let them leave or retry. Prevent duplicate submissions
and excess attachments. Check the keyboard, large text and screenshot picker.
Make sure any extra details the form promises to send are supported by the
feedback service. The recent switch to a feedback page is already complete;
we will keep it.

**Permissions:** Check that the app notices permission changes when the user
returns from phone settings, explains permanent denial and avoids repeated
prompts. Fix gaps we find without rewriting the working WhatsApp folder flow.

**Notifications:** Check that tapping a notification opens the right place even
when the app was closed. Handle timezone changes and make sure cancelling one
notification campaign does not cancel unrelated notifications.

**Ads and links:** Check that premium mode and developer ad switches apply to
all ad placements. Make unsupported ads and missing store/support links behave
clearly on each supported platform.

**Done when:** These failure cases have a usable outcome instead of a stuck page,
a lost action or an unexplained button that does nothing. Record which checks
were actually performed and which still need a device.

## 6. Make the features easier to use in another app

**Problem:** The code has moved ahead of parts of the documentation. Some package
Flutter requirements also disagree with the packages they depend on.

**Changes:**

- Correct the package version requirements and outdated feature lists.
- For forms, developer tools, Kit Lab, permissions, notifications, subscriptions
  and settings, document the packages to add, the setup code and the choices
  each app needs to supply.
- Explain supported platforms, how to preserve existing saved settings and what
  changes when upgrading the kit.
- Add the missing package documentation and update it with the fixes above.

**Done when:** Another developer can add a feature using its guide without
copying Story Saver's WhatsApp-specific code or guessing the setup.

## Work order

Do steps 1–6 in order. Update the relevant documentation as each fix lands.
After each step, report what changed, what was checked and what remains.

This work does not include changing another portfolio app, rewriting the agents
folder, building a general form designer, adding new service providers or
publishing packages. There are no commits or pushes planned.
