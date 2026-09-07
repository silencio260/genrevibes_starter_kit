#!/usr/bin/env bash
set -euo pipefail

# Empties the consolidated package tool caches.
#
# Fifty-one packages resolve independently, so each keeps its own copy of the
# compiled test runner (~23MB) and its own compiled test kernel (~30MB).
# `tool/link_build_dirs.sh` gathers all of it under `submodule-build-dir/`;
# this empties that directory.
#
# The per-package directories themselves are kept. Removing them would leave
# every symlink dangling, and a dangling `.dart_tool` makes `pub get` fail
# outright rather than recreate it.
#
# Nothing here is tracked by git and nothing is needed to build an application:
# an app's own package_config.json names each path dependency directly, so
# `flutter run` and `flutter analyze` at application level are unaffected. The
# only cost is that the next resolve and the next test run start cold.
#
# Usage: tool/clean.sh [--dry-run]

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
central_dir="$repository_root/submodule-build-dir"
dry_run=false

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--dry-run]" >&2
  exit 64
fi

if [[ $# -eq 1 ]]; then
  if [[ "$1" == "--dry-run" ]]; then
    dry_run=true
  else
    echo "Usage: $0 [--dry-run]" >&2
    exit 64
  fi
fi

targets=()

# The consolidated caches.
if [[ -d "$central_dir" ]]; then
  while IFS= read -r directory; do
    targets+=("$directory")
  done < <(find "$central_dir" -mindepth 2 -maxdepth 2 -type d | sort)
fi

# Anything a package created before it was linked, or after a link was lost.
while IFS= read -r directory; do
  targets+=("$directory")
done < <(
  find "$repository_root/packages" "$repository_root/examples" \
    -mindepth 2 -maxdepth 2 -type d \( -name build -o -name .dart_tool \) \
    2>/dev/null | sort
)

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "Nothing to clean."
  exit 0
fi

reclaimed_kb=0
for directory in "${targets[@]}"; do
  size_kb="$(du -sk "$directory" | cut -f1)"
  reclaimed_kb=$((reclaimed_kb + size_kb))
  if [[ $size_kb -gt 1024 ]]; then
    printf '%8.1f MB  %s\n' \
      "$(echo "$size_kb" | awk '{print $1/1024}')" \
      "${directory#"$repository_root"/}"
  fi
done

printf '\n%d directories, %.2f GB\n' \
  "${#targets[@]}" \
  "$(echo "$reclaimed_kb" | awk '{print $1/1048576}')"

if [[ "$dry_run" == true ]]; then
  echo "Dry run: nothing was removed."
  exit 0
fi

for directory in "${targets[@]}"; do
  if [[ "$directory" == "$central_dir"/* ]]; then
    # Keep the directory, and the committed .gitkeep that makes git carry it,
    # so the symlink pointing here stays valid.
    find "$directory" -mindepth 1 -maxdepth 1 ! -name .gitkeep \
      -exec rm -rf {} + 2>/dev/null || true
  else
    rm -rf "$directory"
  fi
done

echo "Removed."
