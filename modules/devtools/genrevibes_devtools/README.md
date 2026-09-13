# genrevibes_devtools

Shared Kit Lab screens, the hidden developer-unlock gesture, module health,
analytics delivery history and kit logs. Requires Flutter 3.27 / Dart 3.6.

Create a `DevToolsHost` with the coordinator, your `DevAnalyticsCatalogue` and
the same provider/controller instances your app uses. Pass that host to
`StarterKitLabScreen`. Capabilities are optional; omitted instances show as not
connected. Connect `rating`, `onboarding` and `localNotifications` to enable their
controls. The Modules page reports disabled, waiting and timed-out modules too.

Pass `developerAccess`; the Lab checks `DeveloperAction.diagnostics` on each
page and responds to revoked access. Apps providing another access mechanism
can explicitly set `requireDeveloperAccess: false`. The shared unlock and
lockout logic lives in `genrevibes_developer_access`.

Use one `RecordingKitLogger` for provider/coordinator logging and the host's
`logger`. Use one `RecordingDeliveryObserver` for the analytics pipeline and
host's `eventLog`. Both retain bounded in-memory history. Dispose them with the
runtime. Story Saver enables history in development builds only; a store build
can show live health but does not retrospectively gain log history on unlock.

The Lab selects no SDKs and imports no vendor packages. Modules make their own
unsupported/platform errors visible when an action is invoked. Guard direct
application entry points as well as using the Lab's built-in guard.

See the [portfolio adoption guide](../../../docs/portfolio-adoption.md) for
configuration, reusable defaults, recording protection and upgrade behavior.

## September hardening

Guard Lab pages, connect rating/onboarding, distinguish module states and requested/applied replay settings. Correct Flutter floor.

See [portfolio adoption](../../../docs/portfolio-adoption.md) and
[implementation/check status](../../../docs/production-hardening-plan.md).
