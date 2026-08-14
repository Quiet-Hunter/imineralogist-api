//! Fetch iMineralogist observations with typed structs, cursor pagination,
//! and rate-limit handling.
//!
//! Usage:
//!     export IMINERALOGIST_API_KEY=imin_your_key_here
//!     cargo run -- --mineral quartz --max 150
//!     cargo run -- --bbox 13.0,45.0,17.0,49.0

use serde::Deserialize;
use std::{env, process, thread, time::Duration};

const BASE_URL: &str = "https://imineralogist.org/api/v1";

// Only the fields this example uses are declared. serde ignores unknown
// JSON fields by default, which is exactly what the API's versioning
// policy asks clients to do (new fields may appear at any time).
#[derive(Deserialize)]
struct Observation {
    observed_at: String,
    location: Location,
    // Option: an observation may have no community consensus yet (null).
    community_consensus: Option<Consensus>,
    web_url: String,
}

#[derive(Deserialize)]
struct Location {
    privacy: String, // "open" or "obscured"
}

#[derive(Deserialize)]
struct Consensus {
    name: String,
}

#[derive(Deserialize)]
struct ListResponse {
    data: Vec<Observation>,
    next_cursor: Option<String>, // None on the last page
}

// All errors share one envelope: {"error": {"code": ..., "message": ...}}
#[derive(Deserialize)]
struct ApiError {
    error: ApiErrorBody,
}

#[derive(Deserialize)]
struct ApiErrorBody {
    code: String,
    message: String,
}

fn main() {
    let api_key = env::var("IMINERALOGIST_API_KEY").unwrap_or_else(|_| {
        eprintln!("Set IMINERALOGIST_API_KEY first (see README).");
        process::exit(1);
    });

    // Parse `--name value` flags. `--max` caps total records; anything else
    // is passed straight through as a query parameter, so every filter from
    // docs/reference.md works: --mineral, --bbox, --q, --user, --mindat_id,
    // --observed_from/--observed_to, --sort, ...
    let mut filters: Vec<(String, String)> = vec![("limit".into(), "100".into())];
    let mut max_records: usize = 100;
    let args: Vec<String> = env::args().skip(1).collect();
    for pair in args.chunks(2) {
        if let [name, value] = pair {
            let name = name.trim_start_matches("--");
            if name == "max" {
                max_records = value.parse().expect("--max takes a number");
            } else {
                filters.push((name.into(), value.clone()));
            }
        }
    }

    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(30))
        .build()
        .expect("failed to build HTTP client");

    let mut cursor: Option<String> = None;
    let mut count = 0usize;
    'pages: loop {
        let mut query = filters.clone();
        if let Some(c) = &cursor {
            // Same filters + cursor from the previous page = next page.
            query.push(("cursor".into(), c.clone()));
        }

        let response = client
            .get(format!("{BASE_URL}/observations"))
            .header("X-API-Key", &api_key)
            .query(&query)
            .send()
            .unwrap_or_else(|err| {
                eprintln!("request failed: {err}");
                process::exit(1);
            });

        if response.status() == reqwest::StatusCode::TOO_MANY_REQUESTS {
            // Rate limited — Retry-After says how many seconds to wait.
            let wait = response
                .headers()
                .get(reqwest::header::RETRY_AFTER)
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.parse().ok())
                .unwrap_or(60);
            eprintln!("rate limited — waiting {wait}s");
            thread::sleep(Duration::from_secs(wait));
            continue; // retry the same page
        }
        if !response.status().is_success() {
            let status = response.status();
            match response.json::<ApiError>() {
                Ok(api_err) => eprintln!("{}: {}", api_err.error.code, api_err.error.message),
                Err(_) => eprintln!("HTTP {status} (no error envelope)"),
            }
            process::exit(1);
        }

        let page: ListResponse = response.json().unwrap_or_else(|err| {
            eprintln!("bad response body: {err}");
            process::exit(1);
        });

        for obs in page.data {
            let name = obs
                .community_consensus
                .map(|c| c.name)
                .unwrap_or_else(|| "(unidentified)".into());
            // "obscured" coordinates are deliberately offset — don't attempt
            // to de-obscure locations.
            println!(
                "{}  {:<24} {:<8} {}",
                obs.observed_at, name, obs.location.privacy, obs.web_url
            );
            count += 1;
            if count >= max_records {
                break 'pages;
            }
        }

        match page.next_cursor {
            Some(next) => cursor = Some(next),
            None => break, // last page
        }
    }

    println!("\n{count} observations. Data © iMineralogist community contributors.");
}
