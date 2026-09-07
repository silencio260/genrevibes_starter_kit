# genrevibes_database

Provider-neutral document database contracts. Models paths, snapshots, queries
and the store interface. It imports no database SDK.

Paths are alternating collection and document segments: `users/u1` is a
document, `users/u1/notes` is a collection. Confusing the two is the most common
mistake against these APIs and normally surfaces as an opaque vendor error, so
`DocumentPath` validates at the boundary and explains what is wrong.

A missing document is a success carrying a snapshot whose `exists` is false,
never a failure. `data` is `null` for an absent document and empty for an empty
one, because the difference matters and an empty-map check loses it.

`DocumentQuery.validate` catches the two errors stores report opaquely: a set
operator such as `whereIn` given a scalar, and a non-positive limit.

`isFromCache` is carried on every snapshot. Offline-capable stores answer from
cache, and a write-then-read that returns cached data has not necessarily
reached the server.
