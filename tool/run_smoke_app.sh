#!/usr/bin/env bash
#
# Runs the native smoke app with credentials injected at build time.
#
# Credentials are never copied into this repository. The source environment
# file is read in place, filtered down to the keys the smoke app actually
# consumes, and passed to Flutter through a private temporary file that is
# deleted when the command exits.
#
# Resolution order for the source file:
#   1. $GENREVIBES_ENV_FILE
#   2. examples/genrevibes_smoke_app/env/{dev,local}.json
#   3. ../../env/dev.json          (Story Saver, when nested as a submodule)
#
# Usage:
#   bash tool/run_smoke_app.sh                     # flutter run
#   bash tool/run_smoke_app.sh build apk --release
#   GENREVIBES_ENV_FILE=/path/to/env.json bash tool/run_smoke_app.sh

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$repository_root/examples/genrevibes_smoke_app"

# Keys the smoke app reads. Anything else in the source file, including
# ad unit IDs, Firebase keys, and third-party server keys, is deliberately
# dropped so it never reaches the compiler or the build artifacts.
allowed_keys='
development_mode
revenue_cat_api_key_android
revenue_cat_api_key_ios
one_signal_app_id
posthog_api_key
posthog_host
mixpanel_token
'

resolve_env_file() {
  if [[ -n "${GENREVIBES_ENV_FILE:-}" ]]; then
    printf '%s' "$GENREVIBES_ENV_FILE"
    return
  fi
  for candidate in "$app_dir/env/dev.json" "$app_dir/env/local.json"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done
  if [[ -f "$repository_root/../../env/dev.json" ]]; then
    printf '%s' "$(cd "$repository_root/../.." && pwd)/env/dev.json"
    return
  fi
  printf ''
}

source_env_file="$(resolve_env_file)"
filtered_env_file=""

cleanup() {
  [[ -n "$filtered_env_file" && -f "$filtered_env_file" ]] && rm -f "$filtered_env_file"
  return 0
}
trap cleanup EXIT INT TERM

if [[ $# -eq 0 ]]; then
  flutter_args=(run)
else
  flutter_args=("$@")
fi

if [[ -z "$source_env_file" ]]; then
  echo "No environment file found. Building without provider credentials."
  echo "The app will start and report every env-driven provider as unconfigured."
  echo "Copy examples/genrevibes_smoke_app/env.example.json to env/local.json to change that."
  cd "$app_dir"
  exec flutter "${flutter_args[@]}"
fi

if [[ ! -f "$source_env_file" ]]; then
  echo "ERROR: environment file not found: $source_env_file" >&2
  exit 1
fi

filtered_env_file="$(mktemp -t genrevibes_smoke_env.XXXXXX)"
chmod 600 "$filtered_env_file"

ALLOWED_KEYS="$allowed_keys" python3 - "$source_env_file" "$filtered_env_file" <<'PY'
import json, os, sys

source_path, target_path = sys.argv[1], sys.argv[2]
allowed = {k for k in os.environ["ALLOWED_KEYS"].split() if k}

with open(source_path) as handle:
    source = json.load(handle)

filtered = {k: v for k, v in source.items() if k in allowed}
dropped = sorted(k for k in source if k not in allowed and not k.startswith("_"))

with open(target_path, "w") as handle:
    json.dump(filtered, handle)

print(f"Env source : {source_path}")
print(f"Injected   : {', '.join(sorted(filtered)) or '(none)'}")
if dropped:
    print(f"Withheld   : {', '.join(dropped)}")
PY

echo
if [[ -n "${GENREVIBES_DRY_RUN:-}" ]]; then
  echo "DRY RUN, not launching. Would run from $app_dir:"
  echo "  flutter ${flutter_args[*]} --dart-define-from-file=<filtered temp file>"
  exit 0
fi

cd "$app_dir"
flutter "${flutter_args[@]}" --dart-define-from-file="$filtered_env_file"
