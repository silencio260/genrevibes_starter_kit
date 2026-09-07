#!/usr/bin/env bash
set -euo pipefail

# Redirects every package's `build/` and `.dart_tool/` into one place.
#
# Fifty-one packages each keep their own tool caches, so the family scatters
# roughly two gigabytes across ninety-seven directories. Neither location is
# configurable: `flutter config --build-dir` is stored in the user's home
# directory and applies to every Flutter project on the machine, and
# `getBuildDirectory()` rejects absolute paths. A symlink per package is the
# only way to move them, so that is what this does:
#
#   packages/<name>/build       ->  submodule-build-dir/<name>/build
#   packages/<name>/.dart_tool  ->  submodule-build-dir/<name>/.dart_tool
#
# This consolidates, it does not shrink. The bytes are identical; they are just
# all under one directory that `tool/clean.sh` can empty in one step.
#
# Existing real directories are moved rather than deleted, so nothing is
# recompiled that does not have to be.
#
# The links are committed, along with a .gitkeep in each target, so a fresh
# clone already has this layout and needs no setup step. Git cannot store an
# empty directory, and a symlink whose target is missing makes `pub get` fail
# outright ("Creation failed, path = '.dart_tool'") rather than recreate it,
# which is why the placeholder is tracked too.
#
# Run this after adding a package, or to repair links that a `flutter clean`
# removed.
#
# Usage: tool/link_build_dirs.sh [--check]
#
#   --check   report what is unlinked and exit non-zero, changing nothing.

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
central_dir_name="submodule-build-dir"
central_dir="$repository_root/$central_dir_name"
check_only=false

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 64
fi

if [[ $# -eq 1 ]]; then
  if [[ "$1" == "--check" ]]; then
    check_only=true
  else
    echo "Usage: $0 [--check]" >&2
    exit 64
  fi
fi

linked=0
already=0
unlinked=0

link_one() {
  local package_dir="$1"
  local cache_name="$2"
  local package_name
  package_name="$(basename "$package_dir")"

  local source_path="$package_dir/$cache_name"
  local target_path="$central_dir/$package_name/$cache_name"
  # Both packages/<name> and examples/<name> sit two levels below the root.
  local relative_target="../../$central_dir_name/$package_name/$cache_name"

  if [[ -L "$source_path" ]]; then
    if [[ "$(readlink "$source_path")" == "$relative_target" ]]; then
      already=$((already + 1))
      # A link can outlive its target, which breaks pub get. Restore it.
      mkdir -p "$target_path"
      return
    fi
    if [[ "$check_only" == true ]]; then
      echo "  wrong target: ${source_path#"$repository_root"/}"
      unlinked=$((unlinked + 1))
      return
    fi
    rm "$source_path"
  elif [[ -e "$source_path" ]]; then
    if [[ "$check_only" == true ]]; then
      echo "  not linked:   ${source_path#"$repository_root"/}"
      unlinked=$((unlinked + 1))
      return
    fi
  elif [[ "$check_only" == true ]]; then
    echo "  not linked:   ${source_path#"$repository_root"/}"
    unlinked=$((unlinked + 1))
    return
  fi

  mkdir -p "$target_path"

  # Preserve anything already compiled instead of forcing a cold rebuild.
  if [[ -d "$source_path" && ! -L "$source_path" ]]; then
    if [[ -n "$(ls -A "$source_path" 2>/dev/null)" ]]; then
      cp -R "$source_path/." "$target_path/"
    fi
    rm -rf "$source_path"
  fi

  ln -s "$relative_target" "$source_path"
  linked=$((linked + 1))
}

for package_dir in "$repository_root"/packages/*/; do
  package_dir="${package_dir%/}"
  [[ -f "$package_dir/pubspec.yaml" ]] || continue
  link_one "$package_dir" build
  link_one "$package_dir" .dart_tool
done

if [[ "$check_only" == true ]]; then
  if [[ $unlinked -eq 0 ]]; then
    echo "All $already cache directories are linked into $central_dir_name/."
    exit 0
  fi
  echo
  echo "$unlinked directories are not linked. Run tool/link_build_dirs.sh."
  exit 1
fi

echo "Linked $linked, already linked $already."
echo "All package caches now live under $central_dir_name/."
