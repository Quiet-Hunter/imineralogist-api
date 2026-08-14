// Fetch iMineralogist observations with typed structs, cursor pagination,
// and rate-limit handling.
//
// Only the standard library is used — no go.mod needed:
//
//	export IMINERALOGIST_API_KEY=imin_your_key_here
//	go run fetch_observations.go -mineral quartz -max 150
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"
)

const baseURL = "https://imineralogist.org/api/v1"

// Only the fields this example uses are declared. The API may add new
// response fields at any time; encoding/json ignores unknown fields, which
// is exactly what the versioning policy asks clients to do.
type Observation struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	ObservedAt string `json:"observed_at"`
	Location   struct {
		Latitude   float64  `json:"latitude"`
		Longitude  float64  `json:"longitude"`
		PrecisionM *float64 `json:"precision_m"` // pointer: may be null
		Privacy    string   `json:"privacy"`     // "open" or "obscured"
	} `json:"location"`
	// Pointer because an observation may have no consensus yet (null).
	CommunityConsensus *struct {
		Name     string `json:"name"`
		MindatID *int   `json:"mindat_id"`
	} `json:"community_consensus"`
	Observer struct {
		Nickname string `json:"nickname"`
	} `json:"observer"`
	WebURL string `json:"web_url"`
}

type listResponse struct {
	Data       []Observation `json:"data"`
	NextCursor *string       `json:"next_cursor"` // null on the last page
}

type apiError struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func main() {
	mineral := flag.String("mineral", "", "substring filter on mineral names")
	bbox := flag.String("bbox", "", "west,south,east,north in WGS84 degrees")
	maxRecords := flag.Int("max", 100, "stop after this many observations")
	flag.Parse()

	apiKey := os.Getenv("IMINERALOGIST_API_KEY")
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "Set IMINERALOGIST_API_KEY first (see README).")
		os.Exit(1)
	}

	client := &http.Client{Timeout: 30 * time.Second}

	// Any GET /observations parameter fits here; all filters combine with AND.
	params := url.Values{"limit": {"100"}}
	if *mineral != "" {
		params.Set("mineral", *mineral)
	}
	if *bbox != "" {
		params.Set("bbox", *bbox)
	}

	count := 0
	for {
		req, err := http.NewRequest("GET", baseURL+"/observations?"+params.Encode(), nil)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		req.Header.Set("X-API-Key", apiKey)

		resp, err := client.Do(req)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}

		if resp.StatusCode == http.StatusTooManyRequests {
			// Rate limited — Retry-After says how many seconds to wait.
			wait, _ := strconv.Atoi(resp.Header.Get("Retry-After"))
			if wait <= 0 {
				wait = 60
			}
			resp.Body.Close()
			fmt.Fprintf(os.Stderr, "rate limited — waiting %ds\n", wait)
			time.Sleep(time.Duration(wait) * time.Second)
			continue // retry the same page
		}
		if resp.StatusCode != http.StatusOK {
			// All errors share one envelope: {"error": {"code", "message"}}
			var apiErr apiError
			if json.NewDecoder(resp.Body).Decode(&apiErr) == nil && apiErr.Error.Code != "" {
				fmt.Fprintf(os.Stderr, "%s: %s\n", apiErr.Error.Code, apiErr.Error.Message)
			} else {
				fmt.Fprintf(os.Stderr, "HTTP %d\n", resp.StatusCode)
			}
			resp.Body.Close()
			os.Exit(1)
		}

		var page listResponse
		err = json.NewDecoder(resp.Body).Decode(&page)
		resp.Body.Close()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}

		for _, obs := range page.Data {
			name := "(unidentified)"
			if obs.CommunityConsensus != nil {
				name = obs.CommunityConsensus.Name
			}
			// Obscured coordinates are deliberately offset — precision_m is
			// the obscuring radius. Don't attempt to de-obscure locations.
			fmt.Printf("%s  %-24s %-8s %s\n", obs.ObservedAt, name, obs.Location.Privacy, obs.WebURL)
			count++
			if count >= *maxRecords {
				fmt.Printf("\n%d observations. Data © iMineralogist community contributors.\n", count)
				return
			}
		}

		if page.NextCursor == nil {
			break // last page
		}
		// Same filters + cursor from the previous page = next page.
		params.Set("cursor", *page.NextCursor)
	}
	fmt.Printf("\n%d observations. Data © iMineralogist community contributors.\n", count)
}
