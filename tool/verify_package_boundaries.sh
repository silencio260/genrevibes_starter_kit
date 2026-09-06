#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repository_root"

neutral_packages=(
  genrevibes_core
  genrevibes_iap
  genrevibes_analytics
  genrevibes_remote_config
  genrevibes_ads
  genrevibes_notifications
  genrevibes_storage
  genrevibes_consent
  genrevibes_app_rating
  genrevibes_feedback
  genrevibes_starter_kit
)

vendor_pattern='in_app_review|url_launcher|feedbacknest_core|onesignal_flutter|flutter_local_notifications|google_mobile_ads|firebase_analytics|firebase_remote_config|posthog_flutter|mixpanel_flutter|mixpanel_flutter_session_replay|purchases_flutter|purchases_ui_flutter|shared_preferences'
failed=0

for package_name in "${neutral_packages[@]}"; do
  package_path="packages/$package_name"
  if grep -REn "package:($vendor_pattern)" "$package_path/lib" >/dev/null; then
    echo "ERROR: neutral package $package_name imports a vendor SDK"
    grep -REn "package:($vendor_pattern)" "$package_path/lib"
    failed=1
  fi
  if grep -En "^[[:space:]]+($vendor_pattern):" "$package_path/pubspec.yaml" >/dev/null; then
    echo "ERROR: neutral package $package_name declares a vendor SDK"
    grep -En "^[[:space:]]+($vendor_pattern):" "$package_path/pubspec.yaml"
    failed=1
  fi
done

while IFS= read -r dart_file; do
  while IFS= read -r imported_vendor; do
    case "$imported_vendor:$dart_file" in
      google_mobile_ads:packages/genrevibes_ads_admob/*|google_mobile_ads:packages/genrevibes_ads_admob_ui/*|google_mobile_ads:packages/genrevibes_consent_ump/*) ;;
      onesignal_flutter:packages/genrevibes_notifications_onesignal/*) ;;
      flutter_local_notifications:packages/genrevibes_notifications_local/*) ;;
      firebase_analytics:packages/genrevibes_analytics_firebase/*) ;;
      firebase_remote_config:packages/genrevibes_remote_config_firebase/*) ;;
      posthog_flutter:packages/genrevibes_analytics_posthog/*) ;;
      mixpanel_flutter:packages/genrevibes_analytics_mixpanel/*|mixpanel_flutter_session_replay:packages/genrevibes_analytics_mixpanel_replay/*) ;;
      purchases_flutter:packages/genrevibes_iap_revenuecat/*|purchases_flutter:packages/genrevibes_iap_revenuecat_ui/*|purchases_ui_flutter:packages/genrevibes_iap_revenuecat_ui/*) ;;
      in_app_review:packages/genrevibes_app_rating_in_app_review/*|url_launcher:packages/genrevibes_app_rating_in_app_review/*) ;;
      feedbacknest_core:packages/genrevibes_feedbacknest/*) ;;
      shared_preferences:packages/genrevibes_remote_config_shared_preferences/*|shared_preferences:packages/genrevibes_storage_shared_preferences/*) ;;
      *)
        echo "ERROR: $imported_vendor is imported outside its isolated adapter: $dart_file"
        failed=1
        ;;
    esac
  done < <(sed -nE "s/.*package:($vendor_pattern)\/.*/\1/p" "$dart_file" | sort -u)
done < <(find packages -path '*/lib/*.dart' -type f | sort)

coordinator_dependencies="$(
  awk '
    /^dependencies:/ { in_dependencies = 1; next }
    /^dev_dependencies:/ { in_dependencies = 0 }
    in_dependencies && /^  [a-zA-Z0-9_]+:/ {
      dependency = $1
      sub(/:$/, "", dependency)
      print dependency
    }
  ' packages/genrevibes_starter_kit/pubspec.yaml
)"
if [[ "$coordinator_dependencies" != "genrevibes_core" ]]; then
  echo "ERROR: coordinator runtime dependencies must contain only genrevibes_core"
  printf '%s\n' "$coordinator_dependencies"
  failed=1
fi

if [[ $failed -ne 0 ]]; then
  exit 1
fi

echo "Package dependency boundaries are valid."
