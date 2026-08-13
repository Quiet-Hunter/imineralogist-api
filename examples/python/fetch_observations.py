"""Fetch recent iMineralogist observations for a mineral and save them as CSV.

Requires Python 3.10+

Usage:
    export IMINERALOGIST_API_KEY=imin_your_key_here
    python fetch_observations.py --mineral quartz --limit 100 --out quartz.csv
"""

import argparse
import csv
import os
import sys

import requests

BASE_URL = "https://imineralogist.org/api/v1"


def fetch_observations(api_key: str, mineral: str | None, limit: int):
    """Yield observations, following pagination until `limit` records."""
    session = requests.Session()
    session.headers["X-API-Key"] = api_key
    fetched = 0
    cursor = None
    while fetched < limit:
        params = {"limit": min(100, limit - fetched)}
        if mineral:
            params["mineral"] = mineral
        if cursor:
            params["cursor"] = cursor
        response = session.get(f"{BASE_URL}/observations", params=params, timeout=30)
        if response.status_code == 429:
            retry = int(response.headers.get("Retry-After", "60"))
            print(f"Rate limited — waiting {retry}s", file=sys.stderr)
            import time

            time.sleep(retry)
            continue
        response.raise_for_status()
        payload = response.json()
        for observation in payload["data"]:
            yield observation
            fetched += 1
        cursor = payload["next_cursor"]
        if not cursor:
            break


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mineral", help="Mineral name filter, e.g. quartz")
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--out", default="observations.csv")
    args = parser.parse_args()

    api_key = os.environ.get("IMINERALOGIST_API_KEY")
    if not api_key:
        sys.exit("Set IMINERALOGIST_API_KEY first (see README).")

    with open(args.out, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            ["id", "title", "consensus", "latitude", "longitude", "privacy",
             "observed_at", "observer", "web_url"]
        )
        count = 0
        for obs in fetch_observations(api_key, args.mineral, args.limit):
            consensus = obs["community_consensus"] or {}
            location = obs["location"] or {}
            writer.writerow(
                [obs["id"], obs["title"], consensus.get("name", ""),
                 location.get("latitude"), location.get("longitude"),
                 location.get("privacy"), obs["observed_at"],
                 obs["observer"]["nickname"], obs["web_url"]]
            )
            count += 1
    print(f"Wrote {count} observations to {args.out}")
    print("Data © iMineralogist community contributors — attribute observers when publishing.")


if __name__ == "__main__":
    main()
