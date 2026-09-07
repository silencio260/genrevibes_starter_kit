#!/usr/bin/env bash
set -euo pipefail

# Repair the consolidated cache layout before doing anything else.
#
# Every package's build/ and .dart_tool/ is a symlink into
# submodule-build-dir/. Dart's createSync throws on a dangling symlink rather
# than creating the target, so a missing directory does not heal itself: pub
# get fails and `flutter test` crashes the tool outright. Pub runs no user
# scripts on `pub get`, so there is no hook to attach this to. Every command
# this repository owns therefore repairs the layout on entry.
"$(cd "$(dirname "$0")" && pwd)"/link_build_dirs.sh >/dev/null

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
  genrevibes_crash
  genrevibes_engagement
  genrevibes_remote_policy
  genrevibes_permissions
  genrevibes_device_identity
  genrevibes_app_links
  genrevibes_auth
  genrevibes_database
  genrevibes_starter_kit
)

vendor_pattern='firebase_auth|cloud_firestore|app_tracking_transparency|share_plus|permission_handler|device_info_plus|firebase_crashlytics|in_app_review|url_launcher|feedbacknest_core|onesignal_flutter|flutter_local_notifications|google_mobile_ads|firebase_analytics|firebase_remote_config|posthog_flutter|mixpanel_flutter|mixpanel_flutter_session_replay|purchases_flutter|purchases_ui_flutter|shared_preferences'
failed=0

for package_name in "${neutral_packages[@]}"; do
  package_path="$(find modules -mindepth 2 -maxdepth 2 -type d -name "$package_name")"
  if [[ -z "$package_path" ]]; then
    echo "ERROR: neutral package $package_name is not under modules/"
    failed=1
    continue
  fi
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

# A package may import only the vendor SDKs it declares itself.
#
# This replaces a hand-maintained allowlist of package/vendor pairs. The
# allowlist had to be edited for every new adapter and silently went stale when
# one was missed; deriving the rule from each pubspec cannot drift. It is also
# stricter: it catches a package importing a vendor it picked up transitively
# rather than declared, which the allowlist permitted.
#
# Neutral packages are covered by the loop above, which forbids them from
# declaring a vendor at all, so "declares it" can never make one of them legal.
while IFS= read -r pubspec; do
  package_dir="$(dirname "$pubspec")"
  package_name="$(basename "$package_dir")"
  [[ -d "$package_dir/lib" ]] || continue

  # No declared vendor is the normal case, and grep exits non-zero for it,
  # which pipefail would otherwise treat as a script failure.
  declared="$(
    { grep -En "^[[:space:]]+($vendor_pattern):" "$pubspec" 2>/dev/null || true; } |
      sed -E "s/^[0-9]+:[[:space:]]+($vendor_pattern):.*/\1/" | sort -u
  )"

  while IFS= read -r imported_vendor; do
    [[ -n "$imported_vendor" ]] || continue
    if ! printf '%s\n' "$declared" | grep -qx "$imported_vendor"; then
      echo "ERROR: $package_name imports $imported_vendor without declaring it"
      failed=1
    fi
  done < <(
    { find "$package_dir/lib" -name '*.dart' -type f -exec \
      sed -nE "s/.*package:($vendor_pattern)\/.*/\1/p" {} + 2>/dev/null || true; } | sort -u
  )
done < <(find modules -mindepth 3 -maxdepth 3 -name pubspec.yaml | sort)

# The archived monolith is a behavior reference, never a dependency.
if grep -RIlE "deprecated_old_version_1|package:genrevibes_starter_kit_legacy" modules examples --include='*.dart' --include='pubspec.yaml' 2>/dev/null | grep -q .; then
  echo "ERROR: something imports the archived legacy kit"
  grep -RIlE "deprecated_old_version_1|package:genrevibes_starter_kit_legacy" modules examples --include='*.dart' --include='pubspec.yaml'
  failed=1
fi

coordinator_dependencies="$(
  awk '
    /^dependencies:/ { in_dependencies = 1; next }
    /^dev_dependencies:/ { in_dependencies = 0 }
    in_dependencies && /^  [a-zA-Z0-9_]+:/ {
      dependency = $1
      sub(/:$/, "", dependency)
      print dependency
    }
  ' modules/foundation/genrevibes_starter_kit/pubspec.yaml
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
