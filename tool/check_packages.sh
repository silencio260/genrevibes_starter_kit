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
flutter_command_name="flutter"
# `command -v` failing under `set -e` exits with no message at all, which
# reads as a silent pass. Say what is wrong instead.
if ! command -v "$flutter_command_name" >/dev/null 2>&1; then
  echo "ERROR: '$flutter_command_name' is not on PATH." >&2
  echo "Add the Flutter SDK's bin directory to PATH and run this again." >&2
  exit 69
fi
flutter_command="$(command -v "$flutter_command_name")"
dart_command="$(dirname "$flutter_command")/dart"

bash tool/verify_package_boundaries.sh

for package_path in modules/*/*; do
  if [[ ! -f "$package_path/pubspec.yaml" ]]; then
    continue
  fi

  package_name="$(basename "$package_path")"
  printf '\n[%s]\n' "$package_name"
  (
    cd "$package_path"
    "$flutter_command" pub get
    "$dart_command" format --output=none --set-exit-if-changed lib test 2>/dev/null ||
      "$dart_command" format --output=none --set-exit-if-changed lib
    "$flutter_command" analyze
    if [[ -d test ]]; then
      "$flutter_command" test --no-pub
    fi
  )
done
