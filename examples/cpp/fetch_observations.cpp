// Fetch iMineralogist observations with cursor pagination and rate-limit
// handling, using libcurl for HTTP and nlohmann/json for parsing.
//
// Build (macOS, Homebrew):
//   brew install nlohmann-json
//   c++ -std=c++17 fetch_observations.cpp -lcurl -I"$(brew --prefix nlohmann-json)/include" -o fetch_observations
//
// Build (Debian/Ubuntu):
//   sudo apt install libcurl4-openssl-dev nlohmann-json3-dev
//   g++ -std=c++17 fetch_observations.cpp -lcurl -o fetch_observations
//
// Usage:
//   export IMINERALOGIST_API_KEY=imin_your_key_here
//   ./fetch_observations quartz          # optional mineral filter
#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>

using json = nlohmann::json;

static const std::string kBaseUrl = "https://imineralogist.org/api/v1";

// libcurl hands the response body to this callback in chunks.
static size_t writeToString(char* data, size_t size, size_t nmemb, void* userdata) {
    static_cast<std::string*>(userdata)->append(data, size * nmemb);
    return size * nmemb;
}

struct HttpResponse {
    long status = 0;
    std::string body;
    long retryAfterSeconds = 60; // from the Retry-After header on 429
};

// One GET request with the API-key header. Exits on transport errors;
// HTTP-level errors are returned for the caller to inspect.
static HttpResponse get(const std::string& url, const std::string& apiKey) {
    CURL* curl = curl_easy_init();
    if (!curl) {
        std::cerr << "curl_easy_init failed\n";
        std::exit(1);
    }

    HttpResponse response;
    curl_slist* headers = curl_slist_append(nullptr, ("X-API-Key: " + apiKey).c_str());
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeToString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response.body);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    CURLcode result = curl_easy_perform(curl);
    if (result != CURLE_OK) {
        std::cerr << "request failed: " << curl_easy_strerror(result) << "\n";
        std::exit(1);
    }
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response.status);

    // Retry-After tells us exactly how long to wait when rate limited.
    curl_header* header = nullptr;
    if (curl_easy_header(curl, "Retry-After", 0, CURLH_HEADER, -1, &header) == CURLHE_OK) {
        response.retryAfterSeconds = std::strtol(header->value, nullptr, 10);
        if (response.retryAfterSeconds <= 0) response.retryAfterSeconds = 60;
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    return response;
}

// URL-encode one query-parameter value (bbox commas, mineral names with
// spaces, and pagination cursors all need it).
static std::string urlEncode(const std::string& value) {
    char* escaped = curl_easy_escape(nullptr, value.c_str(), static_cast<int>(value.size()));
    std::string encoded(escaped);
    curl_free(escaped);
    return encoded;
}

int main(int argc, char** argv) {
    const char* apiKey = std::getenv("IMINERALOGIST_API_KEY");
    if (!apiKey) {
        std::cerr << "Set IMINERALOGIST_API_KEY first (see README).\n";
        return 1;
    }
    curl_global_init(CURL_GLOBAL_DEFAULT);

    // Any GET /observations parameter can be appended the same way —
    // bbox, q, user, mindat_id, observed_from/observed_to, sort, ...
    // Full reference: ../docs/reference.md
    std::string baseQuery = "limit=100";
    if (argc > 1) baseQuery += "&mineral=" + urlEncode(argv[1]);

    std::string cursor;
    int count = 0;
    const int maxRecords = 100;
    while (count < maxRecords) {
        std::string url = kBaseUrl + "/observations?" + baseQuery;
        // Same filters + cursor from the previous page = next page.
        if (!cursor.empty()) url += "&cursor=" + urlEncode(cursor);

        HttpResponse response = get(url, apiKey);

        if (response.status == 429) { // rate limited — wait and retry the same page
            std::cerr << "rate limited — waiting " << response.retryAfterSeconds << "s\n";
            std::this_thread::sleep_for(std::chrono::seconds(response.retryAfterSeconds));
            continue;
        }
        if (response.status != 200) {
            // All errors share one envelope: {"error": {"code", "message"}}
            json error = json::parse(response.body, nullptr, /*allow_exceptions=*/false);
            if (error.contains("error")) {
                std::cerr << error["error"]["code"].get<std::string>() << ": "
                          << error["error"]["message"].get<std::string>() << "\n";
            } else {
                std::cerr << "HTTP " << response.status << " (no error envelope)\n";
            }
            return 1;
        }

        json page = json::parse(response.body);
        for (const json& obs : page["data"]) {
            // community_consensus is null until the community agrees on a name.
            const json& consensus = obs["community_consensus"];
            std::string name = consensus.is_null() ? "(unidentified)"
                                                   : consensus["name"].get<std::string>();
            // location.privacy is "open" or "obscured"; obscured coordinates
            // are deliberately offset — don't attempt to de-obscure them.
            std::cout << obs["observed_at"].get<std::string>() << "  " << name << "  ("
                      << obs["location"]["privacy"].get<std::string>() << ")  "
                      << obs["web_url"].get<std::string>() << "\n";
            if (++count >= maxRecords) break;
        }

        if (page["next_cursor"].is_null()) break; // last page
        cursor = page["next_cursor"].get<std::string>();
    }

    std::cout << "\n" << count
              << " observations. Data © iMineralogist community contributors.\n";
    curl_global_cleanup();
    return 0;
}
