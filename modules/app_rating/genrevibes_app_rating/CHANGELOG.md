# Changelog

## Unreleased

- Add `RatingCoordinator.snapshot()`: every stored value, the current
  decision and when the time rules next allow a prompt, without evaluating.
- `reset(triggers: ...)` can also clear named trigger counters, so a
  milestone prompt can be replayed.
- Add `recordAppOpen()` for counting opens outside `initialize()`.

## 0.1.0-dev.1

- Add clock-driven rating eligibility, cooldown, snooze, and opt-out policy.
- Add `RatingOutcomeRouter` for store-versus-feedback routing.
- Add the `StoreReviewProvider` contract and legacy storage-key adoption.
