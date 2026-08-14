# Fetch iMineralogist observations into a data frame and save them as CSV.
#
# Follows cursor pagination and waits out 429 rate limits, so it's safe to
# request a few hundred records for a class exercise or analysis.
#
# Requires: install.packages(c("httr", "jsonlite"))
#
# Usage:
#   Sys.setenv(IMINERALOGIST_API_KEY = "imin_your_key_here")  # or export in shell
#   Rscript fetch_observations.R

library(httr)
library(jsonlite)

BASE_URL <- "https://imineralogist.org/api/v1"

api_key <- Sys.getenv("IMINERALOGIST_API_KEY")
if (api_key == "") stop("Set IMINERALOGIST_API_KEY first (see README).")

# Any GET /observations parameter can go here — all filters combine with AND.
# Full reference: ../docs/reference.md
filters <- list(
  mineral = "quartz",                 # substring match, case-insensitive
  bbox = "13.0,45.0,17.0,49.0",       # west,south,east,north (WGS84 degrees)
  observed_from = "2026-06-01",       # inclusive, field observation date (UTC)
  sort = "newest"
)
max_records <- 200

fetch_observations <- function(filters, max_records) {
  rows <- list()
  cursor <- NULL
  repeat {
    query <- c(filters, list(limit = 100))
    if (!is.null(cursor)) query$cursor <- cursor  # same filters + cursor = next page

    response <- GET(
      paste0(BASE_URL, "/observations"),
      query = query,
      add_headers("X-API-Key" = api_key),
      timeout(30)
    )

    if (status_code(response) == 429) {
      # Rate limited — Retry-After says how many seconds to wait.
      wait <- as.numeric(headers(response)[["retry-after"]] %||% "60")
      message("Rate limited - waiting ", wait, "s")
      Sys.sleep(wait)
      next
    }
    if (http_error(response)) {
      # All errors share one envelope: {"error": {"code", "message"}}
      err <- content(response, as = "parsed")$error
      stop(err$code, ": ", err$message)
    }

    page <- content(response, as = "parsed")
    for (obs in page$data) {
      consensus <- obs$community_consensus
      rows[[length(rows) + 1]] <- data.frame(
        id = obs$id,
        title = obs$title,
        consensus = if (is.null(consensus)) NA else consensus$name,
        latitude = obs$location$latitude,
        longitude = obs$location$longitude,
        # "obscured" coordinates are deliberately offset; precision_m is the
        # obscuring radius. Keep this column so analyses can account for it.
        privacy = obs$location$privacy,
        precision_m = obs$location$precision_m %||% NA,
        observed_at = obs$observed_at,
        observer = obs$observer$nickname,
        web_url = obs$web_url
      )
    }

    cursor <- page$next_cursor  # NULL on the last page
    if (is.null(cursor) || length(rows) >= max_records) break
  }
  do.call(rbind, head(rows, max_records))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

observations <- fetch_observations(filters, max_records)
if (is.null(observations)) stop("No observations matched the filters.")
write.csv(observations, "observations.csv", row.names = FALSE)
cat("Wrote", nrow(observations), "observations to observations.csv\n")
cat("Data (c) iMineralogist community contributors - attribute observers when publishing.\n")
