import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import scholar_api

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / "tests" / "data" / "sample_time_series.csv"


class ScholarApiTests(unittest.TestCase):
    def test_get_api_key_prefers_environment(self):
        with mock.patch.dict(os.environ, {"SERPAPI_API_KEY": "abc123"}, clear=True):
            self.assertEqual(scholar_api.get_api_key(), "abc123")

    def test_profile_graph_rows_include_total_series(self):
        profile = {
            "cited_by": {
                "graph": [
                    {"year": 2024, "citations": 10},
                    {"year": 2025, "citations": 12},
                ]
            }
        }
        rows = scholar_api.profile_graph_rows(profile)
        self.assertEqual(rows, [[2024, 10, "total"], [2025, 12, "total"]])

    def test_citation_rows_expand_paper_years(self):
        detail = {
            "citation": {
                "total_citations": {
                    "table": [
                        {"year": 2024, "citations": 3},
                        {"year": 2025, "citations": 4},
                    ]
                }
            }
        }
        rows = scholar_api.citation_rows("Paper A", detail)
        self.assertEqual(rows, [[2024, 3, "Paper A"], [2025, 4, "Paper A"]])

    def test_build_author_rows_combines_total_and_article_rows(self):
        profile = {
            "articles": [{"title": "Paper A", "citation_id": "cid-1"}],
            "cited_by": {"graph": [{"year": 2024, "citations": 10}]},
        }
        detail_map = {
            "cid-1": {
                "citation": {
                    "total_citations": {
                        "table": [{"year": 2024, "citations": 3}]
                    }
                }
            }
        }
        rows = scholar_api.build_author_rows(profile, detail_map)
        self.assertEqual(rows, [[2024, 10, "total"], [2024, 3, "Paper A"]])


class RScriptSmokeTests(unittest.TestCase):
    def test_analyse_r_writes_summary_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "outputs"
            result = subprocess.run(
                ["Rscript", "analyse.R", str(SAMPLE), str(out_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertTrue((out_dir / "paulgp_summary.csv").exists())
            self.assertTrue((out_dir / "paulgp_hindex.csv").exists())
            self.assertTrue((out_dir / "paulgp_top_papers.csv").exists())

    def test_make_graph_r_writes_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            png_path = Path(tmp) / "paulgp_citation_share.png"
            result = subprocess.run(
                ["Rscript", "make_graph.R", str(SAMPLE), str(png_path)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertTrue(png_path.exists())


if __name__ == "__main__":
    unittest.main()
