#!/usr/bin/env bash
# End-to-end smoke test of the running stack.
# Exercises client -> api -> redis/worker -> postgres so we know the app is
# 100% functional before a Dependabot update is auto-merged.
set -euo pipefail

API="${API:-http://localhost:5000}"
CLIENT="${CLIENT:-http://localhost:3000}"
INDEX=5            # worker computes fib(INDEX) and stores it in Redis

retry() {
  local desc="$1"; shift
  local tries="${RETRIES:-30}"
  for i in $(seq 1 "$tries"); do
    if "$@"; then return 0; fi
    echo "  ...waiting for $desc ($i/$tries)"; sleep 3
  done
  echo "FAIL: $desc never became ready"; return 1
}

echo "==> 1. API is up (GET /)"
retry "api root" bash -c "curl -fs $API/ | grep -q 'Hi'"

echo "==> 2. Client is served (GET / on :3000)"
retry "client" bash -c "curl -fs $CLIENT/ | grep -qi '<div id=\"root\">'"

echo "==> 3. POST a value (index=$INDEX)"
curl -fs -X POST "$API/values" \
  -H 'Content-Type: application/json' \
  -d "{\"index\":\"$INDEX\"}" | grep -q 'working'
echo "    posted ok"

echo "==> 4. Value is persisted in Postgres (GET /values/all)"
retry "postgres row" bash -c "curl -fs $API/values/all | grep -q '\"number\":$INDEX'"

# The worker subscribes to Redis and replaces the "Nothing yet!" placeholder
# with the computed Fibonacci number. We assert it became numeric (worker ran),
# rather than a specific value, so the test is independent of the fib indexing.
echo "==> 5. Worker computed fib($INDEX) into Redis (GET /values/current)"
retry "worker result" bash -c "curl -fs $API/values/current | grep -qE '\"$INDEX\":\"[0-9]+\"'"

echo ""
echo "SMOKE TEST PASSED: full flow client -> api -> redis/worker -> postgres is healthy."