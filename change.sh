#!/usr/bin/env bash
set -euo pipefail

# === Config ===
FILE="build-logic/convention/src/main/kotlin/com/logic/AuxClass.kt"
CLASS_NAME="AuxClass"
ITERATIONS=20   # change if you want more/less cycles

# === Helpers ===

die() { echo "ERROR: $*" >&2; exit 1; }

check_file() {
  [[ -f "$FILE" ]] || die "File not found: $FILE"
  grep -q "class[[:space:]]\+$CLASS_NAME\b" "$FILE" || die "Class '$CLASS_NAME' not found in $FILE"
 # grep -q "fun[[:space:]]\+doSomeWork[[:space:]]*\([[:space:]]*\)[[:space:]]*{" "$FILE" || die "doSomeWork() not found in $FILE"
}

update_do_some_work() {
  local i="$1"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  # Insert a println before the marker comment
  # Keeps indentation, appends a short comment so each iteration is unique
  local tmpfile
  tmpfile="$(mktemp)"

  awk -v iter="$i" -v ts="$ts" '
    BEGIN { inserted=0 }
    {
      if (!inserted && $0 ~ /\/\/[[:space:]]*add content here/) {
        print "        println(" iter ")  // iter " iter " at " ts
        inserted=1
      }
      print
    }
  ' "$FILE" > "$tmpfile"

  mv "$tmpfile" "$FILE"
  echo "Inserted println($i) before marker in $FILE"
}


run_build() {
  local tag="$1"
  echo ">>> $(date -u +%FT%TZ) Running assembleDebug"
  ./gradlew :help -Dscan.tag.$tag
}

# === Main ===
check_file
run_build seed
run_build seed2

for ((i=1; i<=ITERATIONS; i++)); do
  echo "===== CYCLE $i ====="
  update_do_some_work "$i"
  run_build incremental_change_8_14_3
done

echo "===== FINAL BUILD ====="
echo "Done."
