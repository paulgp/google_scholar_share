from __future__ import annotations

import argparse
import csv
from pathlib import Path

from scholar_api import (
    DEFAULT_AUTHOR_ID,
    DEFAULT_NUM_ARTICLES,
    build_author_rows,
    fetch_author_profile,
    fetch_citation_detail,
    get_api_key,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Pull Google Scholar citation time series for an author.")
    parser.add_argument("--author-id", default=DEFAULT_AUTHOR_ID, help="Google Scholar author id")
    parser.add_argument("--output", default="paulgp_time_series.csv", help="Output CSV path")
    parser.add_argument("--api-key", default=None, help="SerpAPI key; defaults to SERPAPI_API_KEY")
    parser.add_argument("--num", type=int, default=DEFAULT_NUM_ARTICLES, help="Number of articles to request")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    api_key = get_api_key(args.api_key)
    profile = fetch_author_profile(args.author_id, api_key, num=args.num)

    detail_map = {}
    for article in profile.get("articles", []):
        citation_id = article.get("citation_id")
        if not citation_id:
            continue
        detail_map[citation_id] = fetch_citation_detail(citation_id, api_key)

    rows = build_author_rows(profile, detail_map)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="") as handle:
        csv.writer(handle).writerows(rows)

    print(f"Wrote {len(rows)} rows to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
