# Changelog

## 0.1.0-dev.2

- Add the optional `ConsentFormPreviewProvider` capability, for showing the
  consent form as a simulated region would see it in development.
- Add `ConsentGate.supportsFormPreview` and `ConsentGate.previewConsentForm`.
- Add the `ConsentSignals` model over the stored IAB TCF v2 and GPP values,
  the optional `ConsentSignalsReader` capability, and
  `ConsentGate.readConsentSignals`.

## 0.1.0-dev.1

- Add neutral consent state, snapshot, and debug configuration models.
- Add the `ConsentProvider` contract for ad-network consent adapters.
- Add `ConsentGate` for sequencing consent ahead of ads and analytics.
