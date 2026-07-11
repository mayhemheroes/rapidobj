#!/usr/bin/env bash
# rapidobj/mayhem/build.sh — build the rapidobj-fuzz libFuzzer harness (+ its standalone reproducer)
# and rapidobj's OWN doctest unit-test suite (NORMAL flags) for mayhem/test.sh.
#
# rapidobj is a HEADER-ONLY C++17 Wavefront .OBJ parser: the whole library is the single header
# include/rapidobj/rapidobj.hpp. So the "fuzzed code" IS the header — compiling the harness with
# $SANITIZER_FLAGS against include/ instruments the parser itself (no separate library to build).
# The harness feeds fuzz bytes to rapidobj::ParseStream (in-memory). rapidobj parses in parallel
# threads, so the harness links pthread.
#
# Build contract from the org base ENV: CC/CXX/SANITIZER_FLAGS/LIB_FUZZING_ENGINE/SRC/
# STANDALONE_FUZZ_MAIN. Override sanitizers per build via --build-arg SANITIZER_FLAGS="...".
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# `=` (not `:=`) for SANITIZER_FLAGS so an explicit empty --build-arg builds with NO sanitizers.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS: -gdwarf-3 keeps DWARF < 4 (clang-19 plain -g emits DWARF-5 which Mayhem triage
# can't read, §6.2 item 10). `:=` keeps any caller override; default is always set.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS

cd "$SRC"

CXXSTD="-std=c++17"
INCLUDES="-I$SRC/include"

# ── 1) libFuzzer harness (the Mayhem target) — header-only, so $SANITIZER_FLAGS instruments the
#       parser. -pthread because rapidobj parses chunks on worker threads. ──────────────────────
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS $CXXSTD $INCLUDES -pthread \
     "$SRC/mayhem/rapidobj-fuzz.cpp" $LIB_FUZZING_ENGINE \
     -o /mayhem/rapidobj-fuzz

# ── 2) standalone (non-fuzzer) reproducer: same harness + LLVM's run-once driver instead of the
#       engine. Compile the C driver with $CC first so its LLVMFuzzerTestOneInput ref keeps C
#       linkage (clang++ would mangle it and miss the harness's extern "C" def). ─────────────────
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS $CXXSTD $INCLUDES -pthread \
     "$SRC/mayhem/rapidobj-fuzz.cpp" /tmp/standalone_main.o \
     -o /mayhem/rapidobj-fuzz-standalone

# ── 3) rapidobj's OWN doctest unit-test suite, built with NORMAL flags so mayhem/test.sh only
#       RUNS it. Compiled directly with clang++ against the system-installed doctest-dev header
#       (apt, offline — no FetchContent/network), which provides /usr/include/doctest/doctest.h.
#       These are real known-answer parsing/material/mtllib assertions (~680 CHECKs) — an honest
#       PATCH oracle. Normal flags (not the fuzz sanitizers) keep it from false-failing on benign UB.
#       TEST_DATA_DIR points to the upstream data directory that ships in the repo. ──────────────
TEST_DATA_DIR="$SRC/tests/data"
UNIT_SRCS=(
    "$SRC/tests/unit-tests/src/test_main.cpp"
    "$SRC/tests/unit-tests/src/test_material_parsing.cpp"
    "$SRC/tests/unit-tests/src/test_mtllib.cpp"
    "$SRC/tests/unit-tests/src/test_parsing.cpp"
)
mkdir -p "$SRC/build-tests/tests/unit-tests"
$CXX -std=c++17 \
     -I"$SRC/include" \
     -I/usr/include \
     -DTEST_DATA_DIR="$TEST_DATA_DIR" \
     "${UNIT_SRCS[@]}" \
     -pthread \
     -o "$SRC/build-tests/tests/unit-tests/unit-tests"

echo "build.sh complete:"
ls -la /mayhem/rapidobj-fuzz /mayhem/rapidobj-fuzz-standalone "$SRC/build-tests"/tests/unit-tests/unit-tests 2>&1 || true
