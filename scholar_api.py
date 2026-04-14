from __future__ import annotations

import os
from typing import Any

from serpapi import GoogleSearch

DEFAULT_AUTHOR_ID = "ldL9aVEAAAAJ"
DEFAULT_NUM_ARTICLES = 40
API_KEY_ENV_VAR = "SERPAPI_API_KEY"


def get_api_key(explicit_api_key: str | None = None) -> str:
    api_key = explicit_api_key or os.environ.get(API_KEY_ENV_VAR, "")
    if not api_key:
        raise RuntimeError(f"Set {API_KEY_ENV_VAR} before running this script")
    return api_key


def fetch_author_profile(author_id: str, api_key: str, num: int = DEFAULT_NUM_ARTICLES) -> dict[str, Any]:
    params = {
        "api_key": api_key,
        "engine": "google_scholar_author",
        "author_id": author_id,
        "hl": "en",
        "num": num,
    }
    return GoogleSearch(params).get_dict()


def fetch_citation_detail(citation_id: str, api_key: str) -> dict[str, Any]:
    params = {
        "api_key": api_key,
        "engine": "google_scholar_author",
        "view_op": "view_citation",
        "citation_id": citation_id,
        "hl": "en",
    }
    return GoogleSearch(params).get_dict()


def profile_graph_rows(profile: dict[str, Any]) -> list[list[Any]]:
    graph = ((profile.get("cited_by") or {}).get("graph") or [])
    return [[row.get("year"), row.get("citations"), "total"] for row in graph]


def citation_rows(title: str, detail: dict[str, Any]) -> list[list[Any]]:
    if detail.get("error"):
        return []
    table = ((((detail.get("citation") or {}).get("total_citations") or {}).get("table")) or [])
    return [[row.get("year"), row.get("citations"), title] for row in table]


def build_author_rows(profile: dict[str, Any], detail_map: dict[str, dict[str, Any]]) -> list[list[Any]]:
    rows = profile_graph_rows(profile)
    for article in profile.get("articles", []):
        title = article.get("title")
        citation_id = article.get("citation_id")
        if not title or not citation_id:
            continue
        rows.extend(citation_rows(title, detail_map.get(citation_id, {})))
    return rows
