# genrevibes_database_firestore

Cloud Firestore implementation of the `DocumentStore` contract declared by
`genrevibes_database`. Firebase must already be initialized by the host before
this module starts.

Paths and queries are validated before the SDK is touched, so a collection path
passed where a document belongs, or `whereIn` given a scalar, returns
`invalidConfiguration` instead of an opaque Firestore error. `watch` and
`watchQuery` surface the same problem as a stream error rather than a silent
empty stream.

Firestore error codes are classified rather than lumped together:
`unavailable` and `deadline-exceeded` become `network`, `permission-denied` and
`unauthenticated` become `permissionDenied`, `cancelled` stays cancellation.
That distinction is what lets an app retry a transport failure and stop
retrying a rules rejection.

The SDK sits behind `FirestoreClient`, an injectable boundary returning neutral
snapshots, so the store is tested without an emulator.
