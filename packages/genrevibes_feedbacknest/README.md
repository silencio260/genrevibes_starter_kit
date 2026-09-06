# genrevibes_feedbacknest

FeedbackNest adapters for GenRevibes. One package serves both feedback
submission and rating capture because both route through the same SDK and the
same `init` call; splitting them would initialize one vendor twice.

`FeedbackNestFeedbackProvider` implements the `FeedbackProvider` contract. It
refuses to start without an API key and refuses to send an empty message, rather
than accepting reports and discarding them. A provider that silently swallows
feedback is worse than none, because the application keeps offering a form that
goes nowhere.

`FeedbackNestRatingObserver` plugs into `RatingCoordinator` and records the score
a user actually gave. This is the half of rating that store analytics cannot see:
low scores never reach a store listing, so without capture they are invisible.
Recording is fire-and-forget, because a rating prompt must not stall or fail when
a reporting backend is unreachable.

The SDK takes `dart:io` files while the neutral contract carries bytes, so the
default client stages attachments in the system temp directory and removes them
once the request completes, successfully or not.

The API key belongs in the application's build-time configuration. Never commit
it to a package or a repository.
