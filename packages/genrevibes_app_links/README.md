# genrevibes_app_links

Where an app lives and how to reach its developer, as one validated value
object, plus the share / rate / contact / privacy / terms actions every app in
the portfolio exposes. No launcher or share plugin in the neutral package.

`AppLinksConfig.validate` turns a missing App Store URL or a stubbed privacy
policy into a composition-time failure instead of a dead button in production;
the hand-rolled versions of these links were Android-only, hardcoded, and had a
Privacy Policy tile that opened nothing.

`AppLinkActions` owns the policy: which store URL for which platform, what the
share text says, what a support email carries (subject plus non-sensitive
diagnostics). A missing link returns `invalidConfiguration`, never a silent
no-op. The `LinkOpener` contract only knows how to launch things;
`genrevibes_app_links_launcher` implements it.
