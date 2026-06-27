"""
Generate Wikimedia seed files used by dbt.

This script creates two seeds:

1. dim_languages.csv
   Resolves Wikimedia language editions and derives mobile variants
   (e.g. en -> en.m).

2. dim_namespaces.csv
   Resolves namespace definitions for every Wikimedia language edition.
   This allows the project to identify namespace pages such as:
   - Main_Page
   - File:
   - User:
   - Category:
   - Template:

These seeds are generated directly from Wikimedia APIs to avoid
maintaining large static mapping files manually.
"""

import requests
import pandas as pd
import csv
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from tqdm import tqdm
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

headers = {
    "User-Agent": (
        "WikipediaAttentionObservatory/2.0 "
        "(https://github.com/your-username/your-repo; your-email@example.com)"
    )
}

# ==========================================================
# LANGUAGE RESOLUTION
# ==========================================================
#
# Wikimedia exposes the list of all language editions through
# the sitematrix API.
#
# We use this endpoint to generate a language dimension that:
# - resolves wiki code -> language name
# - derives mobile editions (en.m, fr.m, etc.)
#
# Mobile traffic is reported separately in pageviews and is
# therefore treated as a first-class analytical dimension.
#
# ==========================================================

logger.info("Requesting language metadata from Wikimedia sitematrix API")

api_url = "https://meta.wikimedia.org/w/api.php"

resp = requests.get(
    api_url,
    params={
        "action": "sitematrix",
        "format": "json"
    },
    headers=headers
)

resp.raise_for_status()

logger.info("Successfully retrieved language metadata")

data = resp.json()

# remove metadata fields that are not language editions
to_exclude = [
    "specials",
    "count",
    "statistic",
    "meta",
    "private",
    "closed"
]

language_data = {
    code: data
    for code, data in data["sitematrix"].items()
    if code not in to_exclude
}

logger.info(
    "Resolved %s Wikimedia language editions",
    len(language_data)
)

# ----------------------------------------------------------
# Build language seed
# ----------------------------------------------------------

logger.info("Building language dimension seed")

language_infos = [
    {
        "wiki_code": language_data[wiki_num]["code"],
        "language_name": language_data[wiki_num]["localname"]
    }
    for wiki_num in language_data
]

# Mobile editions are represented in pageviews by the
# '.m' suffix (e.g. en.m, fr.m).
#
# Rather than storing mobile as separate language entities,
# we derive the mobile flag downstream while preserving
# compatibility with raw pageview data.

language_infos += [
    {
        "wiki_code": f"{lang['wiki_code']}.m",
        "language_name": lang["language_name"]
    }
    for lang in language_infos
]

language_df = pd.DataFrame(language_infos)

language_df["is_mobile"] = (
    language_df["wiki_code"]
    .str.endswith(".m")
)

language_df.to_csv(
    "dbt/seeds/dim_languages.csv",
    index=False
)

logger.info(
    "Generated dim_languages.csv (%s rows)",
    len(language_df)
)

# ==========================================================
# NAMESPACE RESOLUTION
# ==========================================================
#
# Not every Wikimedia page represents a semantic concept.
#
# Examples:
# - File:
# - User:
# - Category:
# - Template:
# - MediaWiki:
#
# These namespaces are language-specific and cannot be
# hardcoded reliably.
#
# We therefore query each Wikimedia edition directly and
# build a namespace dimension that can later be used to:
#
# - classify namespace pages
# - identify unmatched structural traffic
# - improve attention quality analyses
#
# ==========================================================

logger.info("Preparing namespace extraction")

site_urls = [
    {
        "wiki_code": language_data[wiki_num]["code"],
        "language_name": language_data[wiki_num]["localname"],
        "url": language_data[wiki_num]["site"][0]["url"]
    }
    for wiki_num in language_data
    if language_data[wiki_num]["site"]
]

logger.info(
    "Found %s language editions with valid API endpoints",
    len(site_urls)
)

# Retry strategy protects against:
# - Wikimedia throttling
# - temporary network failures
# - API availability issues

session = requests.Session()

retry = Retry(
    total=5,
    backoff_factor=2,
    status_forcelist=[429, 403, 503],
    respect_retry_after_header=True,
)

session.mount(
    "https://",
    HTTPAdapter(max_retries=retry)
)

namespace_count = 0
failed_wikis = 0

logger.info("Starting namespace extraction")

with open(
    "dbt/seeds/dim_namespaces.csv",
    "w",
    newline="",
    encoding="utf-8"
) as f:

    writer = csv.writer(f)

    writer.writerow([
        "namespace_id",
        "canonical_namespace",
        "namespace_name",
        "wiki_code",
        "language_name"
    ])

    for site_url in tqdm(site_urls):

        try:

            logger.debug(
                "Resolving namespaces for %s",
                site_url["wiki_code"]
            )

            resp = session.get(
                site_url["url"] + "/w/api.php",
                params={
                    "action": "query",
                    "meta": "siteinfo",
                    "siprop": "namespaces",
                    "format": "json"
                },
                headers=headers,
                timeout=10
            )

            resp.raise_for_status()

            data = resp.json()

            namespace_rows = 0

            for ns_id, ns_info in (
                data["query"]["namespaces"].items()
            ):

                writer.writerow([
                    ns_id,
                    ns_info.get("canonical", ""),
                    ns_info.get("*", ""),
                    site_url["wiki_code"],
                    site_url["language_name"]
                ])

                namespace_rows += 1
                namespace_count += 1

            logger.debug(
                "Resolved %s namespaces for %s",
                namespace_rows,
                site_url["wiki_code"]
            )

            f.flush()

        except Exception as e:

            failed_wikis += 1

            logger.warning(
                "Namespace extraction failed for %s (%s): %s",
                site_url["wiki_code"],
                site_url["url"],
                e
            )

        finally:

            # Wikimedia API etiquette:
            # avoid hammering hundreds of language editions
            time.sleep(5)

logger.info(
    "Namespace extraction completed: "
    "%s namespaces written across %s wikis "
    "(%s failures)",
    namespace_count,
    len(site_urls),
    failed_wikis
)