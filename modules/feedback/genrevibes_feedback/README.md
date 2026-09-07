# genrevibes_feedback

Provider-neutral user feedback contracts. This package models a submission, its
attachments, and the provider interface. It carries no transport and no vendor
SDK.

Feedback and support requests are separate kinds, because providers route them
differently: feedback lands in a product backlog while a support request expects
a reply. Collapsing the two leaves people waiting for answers that never come.

An email address is optional. Requiring one suppresses feedback from the majority
of users who do not want to be contacted, so `isReplyable` reports whether a
reply is possible rather than gating submission on it.

Attachments carry bytes rather than a path, so the contract assumes no
filesystem and a caller can attach something generated in memory, such as a
rendered screenshot or a redacted log. Submissions copy their collections, so a
report cannot be altered after it is handed to an adapter.

Ratings are submitted separately from prose, because rating services model
scores as their own record type and a score with no written review is still
worth sending.
