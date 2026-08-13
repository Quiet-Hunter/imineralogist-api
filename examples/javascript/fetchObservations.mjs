// Fetch observations inside a bounding box and print a summary.
// Requires Node 18+ (global fetch)
// Usage: IMINERALOGIST_API_KEY=imin_... node fetchObservations.mjs

const BASE_URL = "https://imineralogist.org/api/v1";
const apiKey = process.env.IMINERALOGIST_API_KEY;
if (!apiKey) {
  console.error("Set IMINERALOGIST_API_KEY first (see README).");
  process.exit(1);
}

const params = new URLSearchParams({
  bbox: "13.0,45.0,17.0,49.0", // west,south,east,north
  limit: "50",
});

const response = await fetch(`${BASE_URL}/observations?${params}`, {
  headers: { "X-API-Key": apiKey },
});
if (!response.ok) {
  const body = await response.json().catch(() => null);
  console.error(`HTTP ${response.status}`, body?.error ?? "");
  process.exit(1);
}

const { data, next_cursor: nextCursor, meta } = await response.json();
for (const observation of data) {
  const name = observation.community_consensus?.name ?? "(unidentified)";
  console.log(`${observation.created_at}  ${name.padEnd(20)} ${observation.web_url}`);
}
console.log(`\n${data.length} observations${nextCursor ? " (more pages available)" : ""}`);
console.log(meta.attribution);
