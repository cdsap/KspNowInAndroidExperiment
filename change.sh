#!/usr/bin/env bash
set -euo pipefail

# === Config ===
FILE="build-logic/convention/src/main/kotlin/com/logic/AuxClass.kt"
CLASS_NAME="AuxClass"
ITERATIONS=5   # change if you want more/less cycles

# === Helpers ===

die() { echo "ERROR: $*" >&2; exit 1; }

check_file() {
  [[ -f "$FILE" ]] || die "File not found: $FILE"
  grep -q "class $CLASS_NAME" "$FILE" || die "Class '$CLASS_NAME' not found in $FILE"
}

find_class_closing_brace_line() {
  # Finds the last line that is just a closing brace '}' (possibly with whitespace).
  # We rely on the class closing brace being the final '}' in the file.
  awk '
    /^[[:space:]]*}[[:space:]]*$/ { last = NR }
    END { if (last) print last; else print 0 }
  ' "$FILE"
}

add_private_function() {
  local i="$1"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  # Derive a valid Kotlin identifier (no dashes, etc.)
  local func_name="bump_${i}"

  # Locate the closing brace line of the class (assumed last brace in file)
  local close_line
  close_line="$(find_class_closing_brace_line)"
  [[ "$close_line" -gt 0 ]] || die "Could not find class closing brace in $FILE"

  # Create the new function block (private + unused, non-ABI/public)
  # Note: Indented with 4 spaces to fit typical Kotlin style.
  read -r -d '' FUNC <<EOF || true

    private fun $func_name(): Int {

        return $i
    }

EOF

  # Insert the function just before the class closing brace.
  # Keep a backup, then rewrite atomically.
  local tmpfile
  tmpfile="$(mktemp)"
  {
    head -n $((close_line-1)) "$FILE"
    printf "%s" "$FUNC"
    printf "%s\n" ""
    tail -n +"$close_line" "$FILE"
  } > "$tmpfile"

  mv "$tmpfile" "$FILE"
  echo "Inserted private function '$func_name' into $FILE"
}

run_build() {
  local tag="$1"
  echo ">>> $(date -u +%FT%TZ) Running assembleDebug"
  ./gradlew  help -Dscan.tag.$tag --info
}

# === Main ===
check_file
run_build seed
run_build seed2
for ((i=1; i<=ITERATIONS; i++)); do
  echo "===== CYCLE $i ====="
  echo ">>> Performing change: add new private function inside $CLASS_NAME"
  add_private_function "$i"
  echo "adding the function"
  cat $FILE
  run_build abi_gradle_8_14_3_2_e

done

echo "===== FINAL BUILD ====="
#run_build
echo "Done."
