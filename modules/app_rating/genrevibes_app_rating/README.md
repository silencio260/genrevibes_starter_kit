# genrevibes_app_rating

Provider-neutral app rating policy. This package decides *whether* to ask a user
for a rating and *what follows* their answer. It never presents UI and never
talks to a store, so every rule is deterministic and testable against an
injected clock.

Eligibility combines four conditions: the user has not opted out, the app has
been installed long enough, it has been opened enough times, and no prompt was
shown recently. An application-chosen milestone can force past the timing and
app-open thresholds, but never past an explicit opt-out.

Deferring is not the same as declining. "Maybe later" back-dates the last-prompt
timestamp so exactly the snooze period remains, rather than introducing a second
competing timestamp, and a user who deferred re-qualifies sooner than one who was
never asked.

`RatingOutcomeRouter` owns the rating gate: a satisfied user goes to the public
store listing, a dissatisfied one is offered a private feedback channel instead.
That is policy, so both the store adapter and the feedback adapter sit downstream
of it and neither can redefine it.

Ads suppression and analytics arrive as a hook and an observer rather than
imports, so rating policy depends on neither an ad network nor a measurement
provider. Persistence goes through `genrevibes_storage`; wrap the store in a
`MigratingKeyValueStore` seeded with `RatingKeys.legacyKeys` so adopting this
package does not reset eligibility for existing users.
