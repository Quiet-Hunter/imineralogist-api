// Walk every page of a filtered observation list with cursor pagination,
// handling 429 rate limits along the way.
//
// Requires Node 18+ (global fetch). See fetchObservations.mjs for a
// minimal single-request example.
//
// Usage:
//   export IMINERALOGIST_API_KEY=imin_your_key_here
//   node paginateObservations.mjs --mineral quartz --max 250
//
// Any GET /observations query parameter works as a flag:
//   node paginateObservations.mjs --q granite --sort oldest
//   node paginateObservations.mjs --bbox 13.0,45.0,17.0,49.0 --observed_from 2026-06-01

const BASE_URL = "https://imineralogist.org/api/v1";

const apiKey = process.env.IMINERALOGIST_API_KEY;
if (!apiKey) {
  console.error("Set IMINERALOGIST_API_KEY first (see README).");
  process.exit(1);
}

// Parse `--name value` pairs into filters; `--max` caps total records.
const filters = {};
let maxRecords = 100;
const argv = process.argv.slice(2);
for (let i = 0; i + 1 < argv.length; i += 2) {
  const name = argv[i].replace(/^--/, "");
  if (name === "max") maxRecords = Number(argv[i + 1]);
  else filters[name] = argv[i + 1];
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Async generator: yields observations one by one, fetching pages lazily.
// The caller can `break` at any time without fetching unneeded pages.
async function* observations(filters) {
  let cursor = null;
  do {
    const params = new URLSearchParams({ ...filters, limit: "100" });
    if (cursor) params.set("cursor", cursor); // same filters + cursor = next page

    const response = await fetch(`${BASE_URL}/observations?${params}`, {
      headers: { "X-API-Key": apiKey },
    });

    if (response.status === 429) {
      // Rate limited — the API tells us exactly how long to wait.
      const retryAfter = Number(response.headers.get("Retry-After") ?? "60");
      console.error(`Rate limited — waiting ${retryAfter}s`);
      await sleep(retryAfter * 1000);
      continue; // retry the same page
    }
    if (!response.ok) {
      // All errors share one envelope: {"error": {"code", "message"}}
      const body = await response.json().catch(() => null);
      throw new Error(body?.error ? `${body.error.code}: ${body.error.message}` : `HTTP ${response.status}`);
    }

    const page = await response.json();
    yield* page.data;
    cursor = page.next_cursor; // null on the last page
  } while (cursor);
}

let count = 0;
for await (const obs of observations(filters)) {
  const name = obs.community_consensus?.name ?? "(unidentified)";
  const place =
    obs.location.privacy === "obscured"
      ? `~${obs.location.precision_m} m radius` // deliberately offset — don't de-obscure
      : `${obs.location.latitude}, ${obs.location.longitude}`;
  console.log(`${obs.observed_at}  ${name.padEnd(24)} ${place.padEnd(24)} ${obs.web_url}`);
  if (++count >= maxRecords) break; // generator stops fetching further pages
}
console.log(`\n${count} observations. Data © iMineralogist community contributors.`);
