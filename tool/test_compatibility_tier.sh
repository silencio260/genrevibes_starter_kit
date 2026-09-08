#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <base|local|revenuecat|replay|current> [flutter-command]"
  exit 64
fi

# Repair the consolidated cache layout before doing anything else.
#
# Every package's build/ and .dart_tool/ is a symlink into
# submodule-build-dir/. Dart's createSync throws on a dangling symlink rather
# than creating the target, so a missing directory does not heal itself: pub
# get fails and `flutter test` crashes the tool outright. Pub runs no user
# scripts on `pub get`, so there is no hook to attach this to. Every command
# this repository owns therefore repairs the layout on entry.
"$(cd "$(dirname "$0")" && pwd)"/link_build_dirs.sh >/dev/null

tier="$1"
flutter_command="${2:-flutter}"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"
flutter_command_name="$flutter_command"
# `command -v` failing under `set -e` exits with no message at all, which
# reads as a silent pass. Say what is wrong instead.
if ! command -v "$flutter_command_name" >/dev/null 2>&1; then
  echo "ERROR: '$flutter_command_name' is not on PATH." >&2
  echo "Add the Flutter SDK's bin directory to PATH and run this again." >&2
  exit 69
fi
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
      genrevibes_app_links
      genrevibes_app_links_launcher
      genrevibes_auth
      genrevibes_auth_firebase
      genrevibes_auth_test
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
      genrevibes_database
      genrevibes_database_firestore
      genrevibes_database_test
      genrevibes_device_identity
      genrevibes_devtools
      genrevibes_device_identity_platform
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
    done < <(find "$repository_root/modules" -mindepth 2 -maxdepth 2 -type d | sort)
    ;;
  *)
    echo "Unknown compatibility tier: $tier"
    exit 64
    ;;
esac

"$flutter_command" --version
bash "$repository_root/tool/verify_package_boundaries.sh"

for package_name in "${packages[@]}"; do
  # Packages are grouped by capability under modules/, so the category is
  # resolved rather than written into every tier list.
  package_path="$(
    find "$repository_root/modules" -mindepth 2 -maxdepth 2 -type d \
      -name "$package_name"
  )"
  if [[ -z "$package_path" ]]; then
    echo "ERROR: package $package_name is not under modules/"
    exit 1
  fi
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
