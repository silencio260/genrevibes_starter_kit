# genrevibes_ads_admob

Google Mobile Ads implementation for interstitial, rewarded, and app-open
placements. Provider ad-unit IDs are mapped to stable logical placements in
application-owned configuration. Paid, impression, click, and dismissal events
are emitted through the neutral `AdEvent` stream.

Banner and native-template presentation lives in the separately installable
`genrevibes_ads_admob_ui` package so headless/full-screen consumers do not
resolve Flutter widget APIs they do not use.
