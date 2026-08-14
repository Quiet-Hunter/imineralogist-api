# Changelog

## Docs — 2026-08-14

- Expanded examples: every `GET /observations` parameter in `curl.sh`,
  single-observation fetch in Python, cursor pagination with rate-limit
  handling in JavaScript, and new R, Go, Rust, and C++ examples.
  No API changes.

## v1 — 2026-08

Initial public release.

- `GET /api/v1/observations` — list with bbox/date/user/mineral/text filters,
  cursor pagination.
- `GET /api/v1/observations/{id}` — single observation.
- API keys via profile request + manual approval; 60/min and 5,000/day
  default limits.
