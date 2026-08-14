"""Fetch a single iMineralogist observation by id and print its details.

Demonstrates GET /observations/{id}, the shared error envelope, and the
rate-limit headers. See fetch_observations.py for list filtering,
pagination, and CSV export.

Requires Python 3.10+

Usage:
    export IMINERALOGIST_API_KEY=imin_your_key_here
    python get_observation.py obs_0123456789abcdef0123456789abcdef
"""

import os
import sys

import requests

BASE_URL = "https://imineralogist.org/api/v1"


def get_observation(api_key: str, observation_id: str) -> dict:
    """Return one observation, raising SystemExit with a readable message
    on any API error."""
    response = requests.get(
        f"{BASE_URL}/observations/{observation_id}",
        headers={"X-API-Key": api_key},
        timeout=30,
    )

    # Show how much quota is left — every successful response carries these.
    remaining = response.headers.get("X-RateLimit-Remaining-Minute")
    if remaining is not None:
        print(f"(rate limit: {remaining} requests left this minute)", file=sys.stderr)

    if not response.ok:
        # All errors share one envelope: {"error": {"code": ..., "message": ...}}
        try:
            error = response.json()["error"]
        except (ValueError, KeyError):
            sys.exit(f"HTTP {response.status_code} (no error envelope)")
        if error["code"] == "not_found":
            # Covers both "doesn't exist" and "not publicly visible" —
            # the API deliberately doesn't distinguish the two.
            sys.exit(f"No public observation with id {observation_id}")
        if response.status_code == 429:
            retry_after = response.headers.get("Retry-After", "?")
            sys.exit(f"{error['message']} (retry after {retry_after}s)")
        sys.exit(f"{error['code']}: {error['message']}")

    return response.json()["data"]


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(f"Usage: python {sys.argv[0]} <observation_id>")

    api_key = os.environ.get("IMINERALOGIST_API_KEY")
    if not api_key:
        sys.exit("Set IMINERALOGIST_API_KEY first (see README).")

    obs = get_observation(api_key, sys.argv[1])

    consensus = obs["community_consensus"]
    location = obs["location"]

    print(f"Title:       {obs['title']}")
    print(f"Consensus:   {consensus['name'] if consensus else '(none yet)'}")
    print(f"Observed at: {obs['observed_at']}")
    print(f"Observer:    {obs['observer']['nickname']}")

    # `privacy` is "open" or "obscured". For obscured records the
    # coordinates are deliberately offset and precision_m is the obscuring
    # radius — never try to recover the true location.
    print(
        f"Location:    {location['latitude']}, {location['longitude']} "
        f"({location['privacy']}, ±{location['precision_m']} m)"
    )

    # `source` is "ai" or "user"; `kind` is mineral/formation/fossil.
    for ident in obs["identifications"]:
        confidence = f"{ident['confidence']:.0%}" if ident["confidence"] is not None else "n/a"
        print(f"  candidate: {ident['name']} ({ident['kind']}, {ident['source']}, {confidence})")

    for photo in obs["photos"]:
        print(f"  photo: {photo['url']} ({photo['width']}x{photo['height']})")

    print(f"Web page:    {obs['web_url']}")


if __name__ == "__main__":
    main()
