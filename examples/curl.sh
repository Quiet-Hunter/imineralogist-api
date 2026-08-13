#!/usr/bin/env bash
# Annotated curl examples. Set your key first:
#   export IMINERALOGIST_API_KEY=imin_your_key_here
set -euo pipefail

BASE="https://imineralogist.org/api/v1"
AUTH="X-API-Key: ${IMINERALOGIST_API_KEY:?set IMINERALOGIST_API_KEY first}"

# Latest 5 observations
curl -s "$BASE/observations?limit=5" -H "$AUTH" | head -c 2000 || true; echo

# Quartz observations observed in July 2026
curl -s "$BASE/observations?mineral=quartz&observed_from=2026-07-01&observed_to=2026-07-31" -H "$AUTH"

# Everything inside a bounding box (west,south,east,north)
curl -s "$BASE/observations?bbox=13.0,45.0,17.0,49.0" -H "$AUTH"

# One observation by id
curl -s "$BASE/observations/obs_0123456789abcdef0123456789abcdef" -H "$AUTH"

# Inspect rate-limit headers
curl -sI "$BASE/observations?limit=1" -H "$AUTH" | grep -i x-ratelimit
