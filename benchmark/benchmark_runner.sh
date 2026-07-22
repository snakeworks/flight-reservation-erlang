#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EBIN="$SCRIPT_DIR/../ebin"
RESULTS="$SCRIPT_DIR/results"

# Erlang process limit
PLIMIT="+P 20000000"

mkdir -p "$RESULTS"

for exp in exp1 exp2 exp3; do
  echo "Running $exp..."
  erl $PLIMIT -noshell -pa "$EBIN" -eval "benchmark:${exp}(), init:stop(0)." >"$RESULTS/${exp}.csv"
  echo "Finished $exp, wrote $RESULTS/${exp}.csv"
done

echo "Done."
