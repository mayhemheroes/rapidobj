#!/usr/bin/env bash
# rapidobj/mayhem/test.sh — RUN rapidobj's own doctest unit-test suite (the `unit-tests` binary
# built by mayhem/build.sh with normal flags) and emit a CTRF summary. exit 0 iff no test failed.
#
# PATCH-grade oracle: these are rapidobj's real known-answer parsing tests (ParseStream/ParseFile
# golden results, ParseReals math, material + mtllib parsing — ~680 CHECK assertions). They assert
# BEHAVIOR/OUTPUT, so a no-op "exit(0)" patch cannot pass. This script only RUNS the pre-built
# binary; it never compiles. doctest exits non-zero if any assertion fails and prints a final
# "Status: SUCCESS!"/"FAILURE!" plus a results line we parse for counts.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

BIN="$SRC/build-tests/tests/unit-tests/unit-tests"
[ -x "$BIN" ] || { echo "missing $BIN — run mayhem/build.sh first" >&2; emit_ctrf "doctest" 0 1 0; exit 2; }

# Run doctest with its assertion-success counter on so we can report per-assertion counts. Capture
# output regardless of exit code; doctest exits non-zero iff a test case failed.
out="$("$BIN" --success=false 2>&1)"; rc=$?
echo "$out"

# doctest prints: "[doctest] test cases: <T> | <P> passed | <F> failed | <S> skipped"
line="$(printf '%s\n' "$out" | sed -n 's/.*test cases:.*/&/p' | tail -1)"
passed=$(printf '%s\n'  "$line" | sed -n 's/.*| *\([0-9][0-9]*\) passed.*/\1/p')
failed=$(printf '%s\n'  "$line" | sed -n 's/.*| *\([0-9][0-9]*\) failed.*/\1/p')
skipped=$(printf '%s\n' "$line" | sed -n 's/.*| *\([0-9][0-9]*\) skipped.*/\1/p')

# Fall back to the binary's exit code if the summary line couldn't be parsed.
if [ -z "${passed:-}" ] && [ -z "${failed:-}" ]; then
  echo "could not parse doctest summary; using exit code $rc" >&2
  emit_ctrf "doctest" 0 "$rc"
  exit $?
fi
: "${passed:=0}" "${failed:=0}" "${skipped:=0}"

emit_ctrf "doctest" "$passed" "$failed" "$skipped"
