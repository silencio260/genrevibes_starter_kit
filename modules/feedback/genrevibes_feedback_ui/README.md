# genrevibes_feedback_ui

The feedback and contact page for GenRevibes apps. It collects an email, a
message and optional screenshots, validates them, sends them through any
`FeedbackProvider` (FeedbackNest in the portfolio), and shows whether that
worked.

## Composition

```dart
final sent = await openFeedbackPage(
  context,
  provider: feedbackProvider,
  kind: FeedbackKind.contact, // or FeedbackKind.feedback
  // The colors of the app's settings pages, so the form looks like the screen
  // it was opened from.
  theme: const FeedbackPageTheme(
    appBarColor: settingsGreen,
    appBarForegroundColor: Colors.white,
    centerTitle: true,
    backgroundColor: Colors.white,
    accentColor: settingsGreen,
  ),
  pickScreenshot: () async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return FeedbackAttachment(
      filename: image.name,
      bytes: await image.readAsBytes(),
      mimeType: image.mimeType ?? 'image/jpeg',
    );
  },
);
```

`FeedbackPage` is the same page as a widget, for an app that routes by itself.

## Behavior

- **A page, not a sheet.** It opens like the app's other settings pages, with
  an app bar and a back arrow. `FeedbackPageTheme` takes the app's colors; any
  it leaves null come from `ThemeData`.
- **Kinds.** `contact` requires an email, since it expects a reply, and uses
  the contact wording. `feedback` makes the email optional. Override with
  `requireEmail` and `labels` (`FeedbackPageLabels`, or
  `FeedbackPageLabels.forKind`).
- **Keyboard.** The scaffold makes room for the keyboard and the form scrolls
  in the space left, so every field and the send button stay reachable.
- **Screenshots** appear only when the app passes `pickScreenshot`, up to
  `maxScreenshots` (default 1), as thumbnails the user can remove. The kit
  takes no image picker dependency.
- **Sending.** The button shows progress, and Back waits until sending ends. A
  failure keeps what the user wrote and shows `sendFailed`; success replaces
  the form with a confirmation and Done. `openFeedbackPage` returns whether it
  was sent, and `onSubmitted` reports every attempt with its result.
- **Metadata** reaches the selected provider. FeedbackNest currently rejects
  nonempty metadata as unsupported; do not promise it is delivered.

## September hardening

Bound submissions, guard picker/submission overlap, retain failed forms and add route protection hook. Align Dart floor.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
