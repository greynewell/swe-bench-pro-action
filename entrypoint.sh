#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# SWE-bench Pro Action entrypoint
# Args passed positionally from action.yml
# ──────────────────────────────────────────────

MODE="${1:-preflight}"
BENCHMARK="${2:-swe-bench-pro}"
SAMPLE_SIZE="${3:-}"
TASK_IDS="${4:-}"
FILTER_CATEGORY="${5:-}"
MAX_CONCURRENT="${6:-2}"
TIMEOUT="${7:-300}"
FAIL_FAST="${8:-false}"
CONFIG="${9:-}"
ANTHROPIC_API_KEY="${10:-}"
MODEL="${11:-}"
OUTPUT_FORMAT="${12:-json,junit}"
MCPBR_VERSION="${13:-}"

# Results directory
RESULTS_DIR="${GITHUB_WORKSPACE:-.}/swe-bench-results"
mkdir -p "$RESULTS_DIR"

# ──────────────────────────────────────────────
# Upgrade mcpbr if a specific version is requested
# ──────────────────────────────────────────────
if [ -n "$MCPBR_VERSION" ]; then
    echo "::group::Installing mcpbr==${MCPBR_VERSION}"
    pip install --no-cache-dir --force-reinstall "mcpbr==${MCPBR_VERSION}"
    echo "::endgroup::"
fi

echo "mcpbr version: $(mcpbr --version 2>&1 || echo 'unknown')"

# ──────────────────────────────────────────────
# Export API key if provided
# ──────────────────────────────────────────────
if [ -n "$ANTHROPIC_API_KEY" ]; then
    export ANTHROPIC_API_KEY
fi

# ──────────────────────────────────────────────
# Verify Docker is accessible
# ──────────────────────────────────────────────
if ! docker info > /dev/null 2>&1; then
    echo "::error::Docker is not accessible. Ensure the runner has Docker and the socket is mounted."
    exit 1
fi

# ──────────────────────────────────────────────
# Cleanup trap — stop any SWE-bench containers on exit
# ──────────────────────────────────────────────
cleanup() {
    echo "Cleaning up SWE-bench containers..."
    docker ps -q --filter "label=mcpbr" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
}
trap cleanup EXIT SIGTERM SIGINT

# ──────────────────────────────────────────────
# Build the mcpbr command
# ──────────────────────────────────────────────
CMD=()

if [ "$MODE" = "preflight" ]; then
    CMD=(mcpbr preflight)
    CMD+=(-b "$BENCHMARK")
    CMD+=(--max-concurrent "$MAX_CONCURRENT")
    CMD+=(--timeout "$TIMEOUT")

    if [ -n "$SAMPLE_SIZE" ]; then
        CMD+=(-n "$SAMPLE_SIZE")
    fi

    if [ -n "$TASK_IDS" ]; then
        IFS=',' read -ra TASKS <<< "$TASK_IDS"
        for task in "${TASKS[@]}"; do
            task="$(echo "$task" | xargs)"  # trim whitespace
            CMD+=(--task "$task")
        done
    fi

    if [ -n "$FILTER_CATEGORY" ]; then
        CMD+=(--filter-category "$FILTER_CATEGORY")
    fi

    if [ "$FAIL_FAST" = "true" ]; then
        CMD+=(--fail-fast)
    fi

    if [ -n "$CONFIG" ]; then
        CMD+=(-c "$CONFIG")
    fi

elif [ "$MODE" = "evaluate" ]; then
    CMD=(mcpbr run)
    CMD+=(-b "$BENCHMARK")

    if [ -z "$CONFIG" ]; then
        echo "::error::Config file is required for evaluate mode. Set the 'config' input."
        exit 1
    fi
    CMD+=(-c "$CONFIG")

    if [ -n "$MODEL" ]; then
        CMD+=(-m "$MODEL")
    fi

    if [ -n "$SAMPLE_SIZE" ]; then
        CMD+=(-n "$SAMPLE_SIZE")
    fi

    if [ -n "$TASK_IDS" ]; then
        IFS=',' read -ra TASKS <<< "$TASK_IDS"
        for task in "${TASKS[@]}"; do
            task="$(echo "$task" | xargs)"
            CMD+=(--task "$task")
        done
    fi

    if [ -n "$FILTER_CATEGORY" ]; then
        CMD+=(--filter-category "$FILTER_CATEGORY")
    fi

    if [ "$FAIL_FAST" = "true" ]; then
        CMD+=(--fail-fast)
    fi

    # Output format flags
    IFS=',' read -ra FORMATS <<< "$OUTPUT_FORMAT"
    for fmt in "${FORMATS[@]}"; do
        fmt="$(echo "$fmt" | xargs)"
        case "$fmt" in
            json)     CMD+=(-o "$RESULTS_DIR/results.json") ;;
            junit)    CMD+=(--output-junit "$RESULTS_DIR/results.junit.xml") ;;
            markdown) CMD+=(--output-markdown "$RESULTS_DIR/results.md") ;;
            html)     CMD+=(--output-html "$RESULTS_DIR/results.html") ;;
        esac
    done
else
    echo "::error::Invalid mode '$MODE'. Must be 'preflight' or 'evaluate'."
    exit 1
fi

# ──────────────────────────────────────────────
# Run mcpbr
# ──────────────────────────────────────────────
echo "::group::Running mcpbr ${MODE}"
echo "Command: ${CMD[*]}"
echo ""

EXIT_CODE=0
"${CMD[@]}" 2>&1 | tee "$RESULTS_DIR/output.log" || EXIT_CODE=$?

echo "::endgroup::"
echo "mcpbr exited with code: $EXIT_CODE"

# ──────────────────────────────────────────────
# Parse results and set outputs
# ──────────────────────────────────────────────
TOTAL=0
PASSED=0
FAILED=0
RATE="0.0"

if [ "$MODE" = "preflight" ]; then
    # Parse preflight output from log
    if [ -f "$RESULTS_DIR/output.log" ]; then
        # Extract pass/fail counts from mcpbr preflight output.
        # These patterns match mcpbr's status lines (e.g., "PASS: django__django-16046").
        # grep -c exits 1 on no match, so || true is needed.
        PASSED=$(grep -c "^PASS" "$RESULTS_DIR/output.log" || true)
        FAILED=$(grep -c "^FAIL" "$RESULTS_DIR/output.log" || true)
        # Ensure numeric values (strip any whitespace)
        PASSED="${PASSED//[^0-9]/}"
        FAILED="${FAILED//[^0-9]/}"
        PASSED="${PASSED:-0}"
        FAILED="${FAILED:-0}"
        TOTAL=$((PASSED + FAILED))
        if [ "$TOTAL" -gt 0 ]; then
            RATE=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc 2>/dev/null || echo "0.0")
        fi
    fi
elif [ -f "$RESULTS_DIR/results.json" ]; then
    # Parse JSON results from evaluate mode
    TOTAL=$(jq -r '.total // .summary.total // 0' "$RESULTS_DIR/results.json" 2>/dev/null || echo "0")
    PASSED=$(jq -r '.passed // .summary.passed // 0' "$RESULTS_DIR/results.json" 2>/dev/null || echo "0")
    FAILED=$(jq -r '.failed // .summary.failed // 0' "$RESULTS_DIR/results.json" 2>/dev/null || echo "0")
    RATE=$(jq -r '.success_rate // .summary.success_rate // "0.0"' "$RESULTS_DIR/results.json" 2>/dev/null || echo "0.0")
fi

# Write outputs
{
    echo "results-path=$RESULTS_DIR"
    echo "total=$TOTAL"
    echo "passed=$PASSED"
    echo "failed=$FAILED"
    echo "success-rate=$RATE"
} >> "${GITHUB_OUTPUT:-/dev/null}"

# ──────────────────────────────────────────────
# Write job summary
# ──────────────────────────────────────────────
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
        echo "## SWE-bench Pro — ${MODE^} Results"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Benchmark | \`$BENCHMARK\` |"
        echo "| Total | $TOTAL |"
        echo "| Passed | $PASSED |"
        echo "| Failed | $FAILED |"
        echo "| Success Rate | ${RATE}% |"
        echo ""
        if [ "$EXIT_CODE" -eq 0 ]; then
            echo "> **Status:** All checks passed"
        else
            echo "> **Status:** Completed with failures (exit code $EXIT_CODE)"
        fi
    } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$EXIT_CODE"
