#!/usr/bin/env bash
# Annotated curl examples for the iMineralogist public API.
#
# Every query parameter of GET /observations is demonstrated below.
# Full parameter reference: ../docs/reference.md
#
# Set your key first:
#   export IMINERALOGIST_API_KEY=imin_your_key_here
#
# Tip: pipe any of these through `jq` for readable output, e.g.
#   curl -s "$BASE/observations?limit=2" -H "$AUTH" | jq .
set -euo pipefail

BASE="https://imineralogist.org/api/v1"
AUTH="X-API-Key: ${IMINERALOGIST_API_KEY:?set IMINERALOGIST_API_KEY first}"

# ---------------------------------------------------------------------------
# Basics
# ---------------------------------------------------------------------------

# Latest 5 observations (default sort: newest first).
curl -s "$BASE/observations?limit=5" -H "$AUTH" | head -c 2000 || true; echo

# One observation by id. Returns 404 `not_found` for ids that don't exist
# or aren't publicly visible — the API doesn't distinguish the two.
curl -s "$BASE/observations/obs_0123456789abcdef0123456789abcdef" -H "$AUTH"

# ---------------------------------------------------------------------------
# Filtering — all parameters combine with AND
# ---------------------------------------------------------------------------

# By mineral name. Case-insensitive substring match against the community
# consensus name AND all identification candidates, so `fluor` matches
# Fluorite and `quartz` matches Smoky Quartz.
curl -s "$BASE/observations?mineral=quartz" -H "$AUTH"

# By exact mindat.org id (3337 = Quartz). More precise than `mineral` —
# use this when you already know which species you want.
curl -s "$BASE/observations?mindat_id=3337" -H "$AUTH"

# Free-text search in title and notes (substring, case-insensitive).
curl -s "$BASE/observations?q=granite" -H "$AUTH"

# By observer. `user` is the public user id — the last path segment of
# https://imineralogist.org/users/{id}.
curl -s "$BASE/observations?user=abc123" -H "$AUTH"

# Inside a bounding box: west,south,east,north in WGS84 degrees.
# Filters on the observation's PUBLIC coordinates — records with obscured
# locations match on their offset coordinates, not the true ones.
curl -s "$BASE/observations?bbox=13.0,45.0,17.0,49.0" -H "$AUTH"

# Observed in July 2026 (inclusive range on the field observation date, UTC).
curl -s "$BASE/observations?observed_from=2026-07-01&observed_to=2026-07-31" -H "$AUTH"

# Published (created) since a date — useful for periodic syncs.
curl -s "$BASE/observations?created_from=2026-08-01" -H "$AUTH"

# Oldest first instead of the default newest-first.
curl -s "$BASE/observations?sort=oldest&limit=3" -H "$AUTH"

# Filters compose: quartz observations in a bbox, observed this summer.
curl -s "$BASE/observations?mineral=quartz&bbox=13.0,45.0,17.0,49.0&observed_from=2026-06-01&observed_to=2026-08-31" -H "$AUTH"

# ---------------------------------------------------------------------------
# Pagination — cursor-based
# ---------------------------------------------------------------------------

# Each page returns `next_cursor` (null on the last page). Pass it back as
# `cursor` WITH THE SAME FILTERS to get the next page. Requires jq.
if command -v jq >/dev/null; then
  cursor=""
  for page in 1 2 3; do
    response=$(curl -s "$BASE/observations?mineral=quartz&limit=10${cursor:+&cursor=$cursor}" -H "$AUTH")
    echo "page $page: $(echo "$response" | jq '.data | length') observations"
    cursor=$(echo "$response" | jq -r '.next_cursor // empty')
    [ -n "$cursor" ] || break   # null cursor = no more pages
  done
else
  echo "jq not installed — skipping pagination demo" >&2
fi

# ---------------------------------------------------------------------------
# Rate limits and errors
# ---------------------------------------------------------------------------

# Every successful response carries your remaining per-minute and per-day
# quota. A 429 response includes Retry-After (seconds to wait).
curl -sI "$BASE/observations?limit=1" -H "$AUTH" | grep -i x-ratelimit

# All errors share one envelope: {"error": {"code": ..., "message": ...}}.
# A request without a key → 401 missing_api_key:
curl -s "$BASE/observations?limit=1"; echo

# An invalid parameter → 400 invalid_parameter (limit must be 1–100):
curl -s "$BASE/observations?limit=999" -H "$AUTH"; echo
