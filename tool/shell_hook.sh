#!/usr/bin/env bash
# Makes `flutter` and `dart` repair this repository's cache layout before they
# run, so `flutter test`, `flutter pub get` and `dart pub get` work even if
# submodule-build-dir/ has been deleted.
#
# Why a shell hook. Every package's build/ and .dart_tool/ is a symlink into
# submodule-build-dir/. Dart's createSync throws on a dangling symlink instead
# of creating the target, so a deleted directory does not heal itself: pub get
# fails and flutter test crashes the tool. Pub deliberately runs no user
# scripts on `pub get`, and the flutter and dart binaries have no hook a
# repository can register, so the shell is the only interception point that
# covers commands typed by hand. Commands this repository owns repair
# themselves already; this extends that to the toolchain.
#
# Install once, in ~/.zshrc or ~/.bashrc:
#
#   source /path/to/genrevibes_starter_kit/tool/shell_hook.sh
#
# Scope. The wrappers run everywhere but act nowhere else: they walk up from
# the working directory looking for a repository that has
# tool/link_build_dirs.sh, and do nothing when there is none. Every other
# Flutter project on the machine is untouched, and the added cost there is a
# handful of stat calls.
#
# To remove it, delete the source line. Nothing else is modified.

_genrevibes_kit_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -x "$dir/tool/link_build_dirs.sh" && -d "$dir/packages" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="${dir%/*}"
  done
  return 1
}

_genrevibes_repair_caches() {
  local root
  root="$(_genrevibes_kit_root)" || return 0

  # The common case: everything is present, so cost nothing.
  if [[ -d "$root/submodule-build-dir" ]]; then
    # Still confirm the package being worked in, since a single target can go
    # missing on its own after a `flutter clean`.
    local package="$PWD"
    while [[ "$package" != "$root" && -n "$package" ]]; do
      if [[ "${package%/*}" == "$root/packages" ]]; then
        if [[ -d "$package/build" && -d "$package/.dart_tool" ]]; then
          return 0
        fi
        break
      fi
      package="${package%/*}"
    done
    [[ "$package" == "$root" ]] && return 0
  fi

  "$root/tool/link_build_dirs.sh" >/dev/null 2>&1 || true
}

flutter() {
  _genrevibes_repair_caches
  command flutter "$@"
}

dart() {
  _genrevibes_repair_caches
  command dart "$@"
}
