# iMineralogist Public API

A free, read-only HTTP API for the [iMineralogist](https://imineralogist.org)
community dataset: publicly shared mineral observations with photos,
identifications, and map locations. Built for classrooms, student projects,
and research.

- **Base URL:** `https://imineralogist.org/api/v1`
- **Format:** JSON over HTTPS, `GET` only
- **Auth:** API key in the `X-API-Key` header

## Getting a key

1. Sign in at [imineralogist.org](https://imineralogist.org) (free account).
2. Open your **profile**, then **Settings → API access**.
3. Tell us what you're building and submit the request.
4. Requests are reviewed manually. Once approved, your key appears in
   **Settings → API access**. Details:
   [imineralogist.org/developers](https://imineralogist.org/developers).

## Quickstart

```bash
curl "https://imineralogist.org/api/v1/observations?mineral=quartz&limit=5" \
  -H "X-API-Key: imin_your_key_here"
```

```python
import requests

response = requests.get(
    "https://imineralogist.org/api/v1/observations",
    params={"bbox": "13.0,45.0,17.0,49.0", "limit": 20},
    headers={"X-API-Key": "imin_your_key_here"},
)
for observation in response.json()["data"]:
    print(observation["title"], observation["web_url"])
```

Runnable, commented examples live in [`examples/`](examples/):

- [`curl.sh`](examples/curl.sh) — every query parameter, pagination, rate
  limits, and the error envelope
- [`python/`](examples/python/) — export filtered observations to CSV;
  fetch a single observation with error handling
- [`javascript/`](examples/javascript/) — minimal fetch; full cursor
  pagination with `Retry-After` handling (Node 18+)
- [`r/`](examples/r/) — observations as a data frame + CSV (httr/jsonlite)
- [`go/`](examples/go/) — typed structs and pagination, stdlib only
- [`rust/`](examples/rust/) — typed structs via serde, reqwest blocking client
- [`cpp/`](examples/cpp/) — libcurl + nlohmann/json, C++17

The full endpoint reference is in [`docs/reference.md`](docs/reference.md).

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /observations` | List public observations. Filter by `bbox`, `observed_from`/`observed_to`, `created_from`/`created_to`, `user`, `mineral`, `mindat_id`, `q`; sort `newest`/`oldest`; paginate with `limit` + `cursor`. |
| `GET /observations/{id}` | One observation with photos, identifications, community consensus, and public location. |

There is no endpoint for AI identification — the API serves existing
community data only.

## Rate limits

Each key gets **60 requests/minute** and **5,000 requests/day** by default
(need more? reply to your approval email or ask via the contact form).
Every response carries `X-RateLimit-*` headers; exceeding a limit returns
`429` with a `Retry-After` header.

## Errors

All errors share one envelope:

```json
{ "error": { "code": "rate_limited", "message": "Rate limit exceeded. Retry after 21 seconds." } }
```

| HTTP | `code` |
|---|---|
| 401 | `missing_api_key`, `invalid_api_key` |
| 400 | `invalid_parameter` |
| 404 | `not_found` |
| 429 | `rate_limited`, `daily_quota_exceeded` |
| 503 | `public_api_disabled` |

## Data terms & attribution

- Free for **educational, research, and other non-commercial** use.
- **Attribute observers**: each record carries the observer's public
  nickname and a `web_url` back to the observation — link it when you
  publish derived work, and credit **iMineralogist** as the source.
- Mineral names and `mindat_id` values reference
  [mindat.org](https://www.mindat.org) data, licensed
  [CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/) —
  derived datasets should carry a compatible license.
- Locations respect observer privacy: obscured coordinates stay obscured.
  Don't attempt to de-obscure locations.
- Keep your key private — don't commit it or embed it in public web pages.

The example **code** in this repository is MIT-licensed (see
[LICENSE](LICENSE)); the license does not extend to the data.

## Contact

Questions, higher limits, or ideas? Use the
[contact form](https://imineralogist.org/about#contact) or open an issue here.
