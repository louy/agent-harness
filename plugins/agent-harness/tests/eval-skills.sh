#!/usr/bin/env bash
#
# Skill activation eval script.
# Runs test prompts via `claude -p` in parallel and checks whether the expected skill triggered.
# Each test runs 3 times — all 3 must pass.
#
# Usage:
#   ./eval-skills.sh                    # run all tests
#   ./eval-skills.sh --verbose          # show full output on failure
#
# Each test case is: expect_skill "skill-name-or-NONE" "prompt"
#   - "NONE" means the prompt should NOT trigger any skill.
#   - Skill names are matched as substrings (e.g. "api-documentation-style"
#     matches "agent-harness:api-documentation-style").

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR=$(mktemp -d)
REPS=3

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

PIDS=()
CASES=()

run_test() {
  local id="$1"
  local rep="$2"
  local prompt="$3"

  local outfile="$RESULTS_DIR/${id}_${rep}.out"

  claude -p "$prompt" \
    --model sonnet \
    --tools "Skill" \
    --output-format stream-json \
    --verbose \
    --max-turns 2 \
    2>/dev/null > "$outfile" || true

  # Extract triggered skills (only from our plugin)
  python3 -c "
import sys, json
prefix = 'agent-harness:'
skills = set()
for line in open('$outfile'):
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'assistant' and 'message' in obj:
            for block in obj['message'].get('content', []):
                if block.get('type') == 'tool_use' and block.get('name') == 'Skill':
                    s = block.get('input', {}).get('skill', '')
                    if s and s.startswith(prefix): skills.add(s)
    except: pass
for s in sorted(skills): print(s)
" 2>/dev/null > "$RESULTS_DIR/${id}_${rep}.triggered" || true
}

add_test() {
  local expected="$1"
  local prompt="$2"
  local id=${#CASES[@]}
  CASES+=("$expected|$prompt")
  for rep in $(seq 1 $REPS); do
    run_test "$id" "$rep" "$prompt" &
    PIDS+=($!)
  done
}

echo ""
echo "=== Skill Activation Eval ==="
echo ""

# ─── api-documentation-style ────────────────────────────────────────

# Should trigger
add_test "api-documentation-style" "Review this GraphQL description for the User type"
add_test "api-documentation-style" "Write a JSDoc comment for this public API method"
add_test "api-documentation-style" "Check the OpenAPI descriptions in this endpoint"
add_test "api-documentation-style" "Add documentation to these GraphQL fields"
add_test "api-documentation-style" "Review the docstrings on our REST API response types"

# Should NOT trigger
add_test "NONE" "Write a README for this project"
add_test "NONE" "Add inline code comments explaining this function"
add_test "NONE" "What does this function do?"

# ─── Wait for all tests ─────────────────────────────────────────────
echo "Running ${#CASES[@]} tests x $REPS reps ($(( ${#CASES[@]} * REPS )) total) in parallel..."
for pid in "${PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done
echo ""

# ─── Collect results ────────────────────────────────────────────────
PASS=0
FAIL=0
TOTAL=${#CASES[@]}
FAILURES=()

echo "api-documentation-style"
for i in "${!CASES[@]}"; do
  IFS='|' read -r expected prompt <<< "${CASES[$i]}"

  failed_reps=()
  for rep in $(seq 1 $REPS); do
    triggered=$(cat "$RESULTS_DIR/${i}_${rep}.triggered" 2>/dev/null || true)
    triggered=$(echo "$triggered" | tr -d '[:space:]')

    rep_pass=true
    if [[ "$expected" == "NONE" ]]; then
      [[ -n "$triggered" ]] && rep_pass=false
    else
      echo "$triggered" | grep -q "$expected" || rep_pass=false
    fi

    if ! $rep_pass; then
      failed_reps+=("$rep:${triggered:-NONE}")
    fi
  done

  if [[ ${#failed_reps[@]} -eq 0 ]]; then
    PASS=$((PASS + 1))
    printf "  ✓ %s (%d/%d)\n" "$prompt" "$REPS" "$REPS"
  else
    FAIL=$((FAIL + 1))
    passed=$(( REPS - ${#failed_reps[@]} ))
    FAILURES+=("  ✗ \"$prompt\" — $passed/$REPS passed, failures: ${failed_reps[*]}")
    printf "  ✗ %s (%d/%d)\n" "$prompt" "$passed" "$REPS"
    if $VERBOSE; then
      for fr in "${failed_reps[@]}"; do
        rep_num="${fr%%:*}"
        echo "    rep $rep_num got: ${fr#*:}"
        cat "$RESULTS_DIR/${i}_${rep_num}.out" 2>/dev/null | head -10
        echo "    ---"
      done
    fi
  fi
done

echo ""

# ─── Results ─────────────────────────────────────────────────────────
echo "=== Results ==="
echo "  Total: $TOTAL  Pass: $PASS  Fail: $FAIL"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "$f"
  done
fi

echo ""
rm -rf "$RESULTS_DIR"
exit "$FAIL"
