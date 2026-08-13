# Changelog

## v1 — 2026-08

Initial public release.

- `GET /api/v1/observations` — list with bbox/date/user/mineral/text filters,
  cursor pagination.
- `GET /api/v1/observations/{id}` — single observation.
- API keys via profile request + manual approval; 60/min and 5,000/day
  default limits.
