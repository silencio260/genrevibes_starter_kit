#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <base|local|revenuecat|replay|current> [flutter-command]"
  exit 64
fi

tier="$1"
flutter_command="${2:-flutter}"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"
dart_command="$(dirname "$(command -v "$flutter_command")")/dart"

case "$tier" in
  base)
    packages=(
      genrevibes_ads
      genrevibes_ads_admob
      genrevibes_ads_admob_ui
      genrevibes_ads_test
      genrevibes_analytics
      genrevibes_analytics_firebase
      genrevibes_analytics_mixpanel
      genrevibes_analytics_posthog
      genrevibes_analytics_test
      genrevibes_app_rating
      genrevibes_app_rating_in_app_review
      genrevibes_app_rating_test
      genrevibes_consent
      genrevibes_consent_test
      genrevibes_consent_ump
      genrevibes_core
      genrevibes_crash
      genrevibes_crash_crashlytics
      genrevibes_crash_test
      genrevibes_engagement
      genrevibes_feedback
      genrevibes_feedbacknest
      genrevibes_iap
      genrevibes_iap_test
      genrevibes_notifications
      genrevibes_notifications_onesignal
      genrevibes_onboarding
      genrevibes_permissions
      genrevibes_permissions_handler
      genrevibes_settings
      genrevibes_remote_config
      genrevibes_remote_config_firebase
      genrevibes_remote_config_shared_preferences
      genrevibes_remote_policy
      genrevibes_storage
      genrevibes_storage_shared_preferences
      genrevibes_starter_kit
    )
    ;;
  local)
    packages=(genrevibes_notifications_local)
    ;;
  revenuecat)
    packages=(genrevibes_iap_revenuecat genrevibes_iap_revenuecat_ui)
    ;;
  replay)
    packages=(genrevibes_analytics_mixpanel_replay)
    ;;
  current)
    packages=()
    while IFS= read -r package_path; do
      packages+=("$(basename "$package_path")")
    done < <(find "$repository_root/packages" -mindepth 1 -maxdepth 1 -type d | sort)
    ;;
  *)
    echo "Unknown compatibility tier: $tier"
    exit 64
    ;;
esac

"$flutter_command" --version
bash "$repository_root/tool/verify_package_boundaries.sh"

for package_name in "${packages[@]}"; do
  package_path="$repository_root/packages/$package_name"
  printf '\n[%s]\n' "$package_name"
  (
    cd "$package_path"
    "$flutter_command" pub get
    if [[ -d test ]]; then
      "$dart_command" format --output=none --set-exit-if-changed lib test
    else
      "$dart_command" format --output=none --set-exit-if-changed lib
    fi
    "$flutter_command" analyze
    if [[ -d test ]]; then
      "$flutter_command" test --no-pub
    fi
  )
done
