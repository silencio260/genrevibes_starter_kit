# Changelog

## 0.1.0-dev.1

- `recordSession()` now marks the first session of each day active and
  reports its milestone, so apps that stay alive across days (launchers)
  still report day-N returns on resume.
- Adds day 2, 4, 5 and 6 milestones (`retention_day_<n>_returned`), so
  days 1 to 7 have no gaps.

- Add `RetentionTracker`, `EngagementSnapshot`, `UserTargetingPolicy`, canonical
  `EngagementEvents`, the analytics observer, and legacy-key adoption.
