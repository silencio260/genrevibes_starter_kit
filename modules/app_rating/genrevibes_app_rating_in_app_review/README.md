# genrevibes_app_rating_in_app_review

Platform in-app review implementation of the `StoreReviewProvider` contract
declared by `genrevibes_app_rating`. It presents the native review flow and falls
back to the public store listing when that flow is unavailable.

The fallback is a normal path rather than an error path. Both platforms
quota-limit the in-app review flow and decline silently once a user has seen it
recently, so an app that only calls the native flow will drop review requests
from users who deliberately chose to leave one. Supplying store listing URLs
through `InAppReviewConfiguration` gives those users somewhere to go.

Deciding *whether* to ask remains with `RatingCoordinator`. This package only
knows how to present a request once that decision is made.

The plugins sit behind `ReviewClient`, an injectable boundary, so this adapter is
tested without platform channels. Faults are normalized to `KitError` with an
`in_app_review_*` provider code.
