# API Reference

Base URL: `https://imineralogist.org/api/v1` · Auth header: `X-API-Key: imin_…`

## GET /observations

Lists publicly visible observations — each has at least one public photo, and
anything rejected by moderation is excluded. Default order: newest first.

### Query parameters

| Param | Type | Description |
|---|---|---|
| `bbox` | `west,south,east,north` | WGS84 degrees. Filters on the observation's **public** coordinates. Example: `13.0,45.0,17.0,49.0`. |
| `observed_from` / `observed_to` | `YYYY-MM-DD` | Inclusive range on the field observation date (UTC). |
| `created_from` / `created_to` | `YYYY-MM-DD` | Inclusive range on the publication date (UTC). |
| `user` | string ≤128 chars | Public user id (as in `https://imineralogist.org/users/{id}`). |
| `mineral` | string ≤240 chars | Case-insensitive substring match against the community consensus name and all identification candidates. `mineral=fluor` matches Fluorite. |
| `mindat_id` | integer ≥1 | Exact match on the mindat.org id of the consensus or any identification. |
| `q` | string ≤240 chars | Substring search in title and notes. |
| `sort` | `newest` (default) \| `oldest` | Order by publication date. |
| `limit` | 1–100, default 20 | Page size. |
| `cursor` | string ≤400 chars | Opaque pagination cursor from `next_cursor`. Pass the same filters with every page. |

### Response

```json
{
  "data": [
    {
      "id": "obs_2f6c…",
      "title": "Quartz on granite",
      "notes": "Found near the trail junction.",
      "observed_at": "2026-07-20T09:00:00Z",
      "created_at": "2026-08-03T12:00:00Z",
      "location": {
        "latitude": 48.013,
        "longitude": 16.021,
        "precision_m": 2000,
        "privacy": "obscured",
        "label": null
      },
      "photos": [
        {
          "url": "https://imineralogist.org/media/…/full.jpg",
          "thumbnail_url": "https://imineralogist.org/media/…/thumb.jpg",
          "width": 1200,
          "height": 900
        }
      ],
      "identifications": [
        { "name": "Quartz", "mindat_id": 3337, "kind": "mineral", "confidence": 0.82, "source": "ai" }
      ],
      "community_consensus": { "name": "Quartz", "mindat_id": 3337 },
      "observer": { "id": "abc123", "nickname": "RockFan" },
      "likes_count": 4,
      "web_url": "https://imineralogist.org/observations/obs_2f6c…"
    }
  ],
  "next_cursor": "MjAyNi0w…",
  "meta": {
    "attribution": "Data © iMineralogist community contributors. Mineral reference data from mindat.org (CC BY-NC-SA).",
    "docs": "https://github.com/Quiet-Hunter/imineralogist-api"
  }
}
```

Field notes:

- `location.privacy` is `open` or `obscured`. For obscured records the
  coordinates are deliberately offset and `precision_m` is the obscuring
  radius; for open records `precision_m` is the reported GPS accuracy (may
  be `null`). `label` is `null` for obscured records.
- `identifications[].source` is `ai` (suggested by our identification
  assistant) or `user` (added by a person). `identifications[].kind` is
  `mineral`, `formation`, or `fossil`. `community_consensus` is the
  name the community currently agrees on, when there is one.
- `next_cursor` is `null` on the last page.

### Pagination loop (pseudo)

```
cursor = null
do:
  page = GET /observations?…&cursor={cursor}
  process(page.data)
  cursor = page.next_cursor
while cursor
```

## GET /observations/{id}

Returns `{"data": <observation>, "meta": {…}}` with the same observation
shape. `404 not_found` for ids that don't exist **or aren't publicly
visible** — the API does not distinguish the two.

## Rate limit headers

Every successful response includes:

```
X-RateLimit-Limit-Minute: 60
X-RateLimit-Remaining-Minute: 59
X-RateLimit-Limit-Day: 5000
X-RateLimit-Remaining-Day: 4991
```

`429` responses include `Retry-After` (seconds).

## Errors

`{"error": {"code": string, "message": string}}` — codes:
`missing_api_key`, `invalid_api_key` (401); `invalid_parameter` (400);
`not_found` (404); `rate_limited`, `daily_quota_exceeded` (429);
`public_api_disabled` (503); `internal_error` (500, unexpected server error);
`request_failed` (other 4xx/5xx errors).

## Versioning

Breaking changes only ship under a new prefix (`/api/v2`). New response
fields may be added at any time — write clients that ignore unknown fields.
