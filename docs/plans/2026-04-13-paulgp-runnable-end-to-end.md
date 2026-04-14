# Paul GP Runnable Pipeline Implementation Plan

**Goal:** Make the Paul Goldsmith-Pinkham pipeline runnable end-to-end from this repository, refresh `paulgp_time_series.csv`, and produce non-interactive analysis outputs.
**Architecture:** Keep the Python `serpapi` client, but make the repo runnable by declaring it explicitly in `requirements.txt` and wrapping the data pull in a small reusable helper module. Keep the workflow as fetch → analyze → graph, but make the R steps non-interactive and file-producing so they work under `Rscript` and in CI-like shells.
**Tech Stack:** Python 3 stdlib (`json`, `csv`, `urllib`, `argparse`, `unittest`, `subprocess`), R (`tidyverse`, `ggrepel`), SerpAPI HTTP JSON endpoint.

- [x] Task 1: Add failing tests for the Python fetch/transform layer and R script smoke tests ✅
- [x] Task 2: Implement a shared SerpAPI wrapper module and declare the Python dependency ✅
- [x] Task 3: Refactor `pull_data.py` to use the helper and stable CSV writing ✅
- [x] Task 4: Implement a non-interactive analysis script and fix the plotting script ✅
- [x] Task 5: Update documentation and verification commands ✅
- [x] Task 6: Refresh `paulgp_time_series.csv` and verify the full pipeline ✅

### Task 1: Add failing tests for the Python fetch/transform layer and R script smoke tests

**Files:**
- Create: `tests/test_scholar_pipeline.py`
- Create: `tests/data/sample_time_series.csv`
- Create: `tests/tmp/.gitkeep`
- Test: `python3 -m unittest discover -s tests -v`

**Step 1: Write the failing tests**
```python
import csv
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
    def test_profile_graph_rows_include_total_series(self):
        profile = {
            "cited_by": {"graph": [{"year": 2024, "citations": 10}, {"year": 2025, "citations": 12}]}
        }
        rows = scholar_api.profile_graph_rows(profile)
        self.assertEqual(rows, [[2024, 10, "total"], [2025, 12, "total"]])

    def test_citation_rows_expand_paper_years(self):
        detail = {
            "citation": {
                "total_citations": {
                    "table": [{"year": 2024, "citations": 3}, {"year": 2025, "citations": 4}]
                }
            }
        }
        rows = scholar_api.citation_rows("Paper A", detail)
        self.assertEqual(rows, [[2024, 3, "Paper A"], [2025, 4, "Paper A"]])

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
```

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest discover -s tests -v`
Expected: FAIL because `scholar_api` does not exist and the R scripts do not accept CLI arguments or write files.

**Step 3: Write minimal implementation**
```python
# scholar_api.py will expose:
# - fetch_json(params)
# - profile_graph_rows(profile)
# - citation_rows(title, detail)
# - profile_time_series(author_id, api_key, num=40)
# - citation_time_series(citation_id, api_key)
```

**Step 4: Run test to verify it still fails only on missing implementation details**
Run: `python3 -m unittest discover -s tests -v`
Expected: FAIL on unimplemented functions / script behavior, not import path problems.

**Step 5: Commit**
```bash
git add tests/test_scholar_pipeline.py tests/data/sample_time_series.csv tests/tmp/.gitkeep
git commit -m "test: add pipeline regression tests"
```

### Task 2: Implement a shared SerpAPI HTTP helper with stdlib only

**Files:**
- Create: `scholar_api.py`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Add assertions for API-key loading and URL-backed fetch indirection:
```python
class ApiKeyTests(unittest.TestCase):
    def test_get_api_key_prefers_environment(self):
        with mock.patch.dict(os.environ, {"SERPAPI_API_KEY": "abc"}, clear=True):
            self.assertEqual(scholar_api.get_api_key(), "abc")
```

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest discover -s tests -v`
Expected: FAIL with `AttributeError: module 'scholar_api' has no attribute 'get_api_key'`.

**Step 3: Write minimal implementation**
```python
import json
import os
import urllib.parse
import urllib.request

BASE_URL = "https://serpapi.com/search.json"
DEFAULT_API_KEY = os.environ.get("SERPAPI_API_KEY", "")


def get_api_key() -> str:
    api_key = os.environ.get("SERPAPI_API_KEY", DEFAULT_API_KEY)
    if not api_key:
        raise RuntimeError("Set SERPAPI_API_KEY before running this script")
    return api_key


def fetch_json(params: dict) -> dict:
    query = urllib.parse.urlencode(params)
    with urllib.request.urlopen(f"{BASE_URL}?{query}", timeout=90) as response:
        return json.load(response)


def profile_graph_rows(profile: dict) -> list[list]:
    graph = ((profile.get("cited_by") or {}).get("graph") or [])
    return [[row.get("year"), row.get("citations"), "total"] for row in graph]


def citation_rows(title: str, detail: dict) -> list[list]:
    table = ((((detail.get("citation") or {}).get("total_citations") or {}).get("table")) or [])
    return [[row.get("year"), row.get("citations"), title] for row in table]
```

**Step 4: Run test to verify it passes**
Run: `python3 -m unittest discover -s tests -v`
Expected: PASS for the pure-Python helper tests, FAIL only for scripts not yet refactored.

**Step 5: Commit**
```bash
git add scholar_api.py tests/test_scholar_pipeline.py
git commit -m "feat: add stdlib scholar api helper"
```

### Task 3: Refactor `pull_data.py` and `pull_cohorts.py` to use the helper and stable CSV writing

**Files:**
- Modify: `pull_data.py`
- Modify: `pull_cohorts.py`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Add an integration-style test that patches the network helper and verifies row output order:
```python
class PullDataAssemblyTests(unittest.TestCase):
    def test_pull_data_writes_total_and_paper_rows(self):
        profile = {
            "articles": [{"title": "Paper A", "citation_id": "cid-1"}],
            "cited_by": {"graph": [{"year": 2024, "citations": 10}]},
        }
        detail = {
            "citation": {"total_citations": {"table": [{"year": 2024, "citations": 3}]}}
        }
        rows = scholar_api.build_author_rows(profile, {"cid-1": detail})
        self.assertEqual(rows, [[2024, 10, "total"], [2024, 3, "Paper A"]])
```

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest discover -s tests -v`
Expected: FAIL because `build_author_rows` does not exist and `pull_data.py` still imports `serpapi`.

**Step 3: Write minimal implementation**
```python
# pull_data.py
import argparse
import csv
from pathlib import Path

from scholar_api import build_author_rows, citation_time_series, get_api_key, profile_time_series

DEFAULT_AUTHOR_ID = "ldL9aVEAAAAJ"
DEFAULT_OUTPUT = Path("paulgp_time_series.csv")

parser = argparse.ArgumentParser()
parser.add_argument("--author-id", default=DEFAULT_AUTHOR_ID)
parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
args = parser.parse_args()

api_key = get_api_key()
profile = profile_time_series(args.author_id, api_key, num=40)
detail_map = {}
for article in profile.get("articles", []):
    citation_id = article.get("citation_id")
    if citation_id:
        detail_map[citation_id] = citation_time_series(citation_id, api_key)
rows = build_author_rows(profile, detail_map)
with open(args.output, "w", newline="") as handle:
    csv.writer(handle).writerows(rows)
```

```python
# pull_cohorts.py should import get_api_key/profile_time_series and keep its current CSV contract.
```

**Step 4: Run test to verify it passes**
Run: `python3 -m unittest discover -s tests -v`
Expected: PASS for Python tests.

**Step 5: Commit**
```bash
git add pull_data.py pull_cohorts.py scholar_api.py tests/test_scholar_pipeline.py
git commit -m "refactor: remove python serpapi client dependency"
```

### Task 4: Implement a non-interactive analysis script and fix the plotting script

**Files:**
- Modify: `analyse.R`
- Modify: `make_graph.R`
- Test: `tests/test_scholar_pipeline.py`

**Step 1: Write the failing test**
Use the smoke tests from Task 1 and extend them to validate expected columns:
```python
with open(out_dir / "paulgp_summary.csv") as handle:
    header = handle.readline().strip()
self.assertEqual(header, "metric,value")
```

**Step 2: Run test to verify it fails**
Run: `python3 -m unittest discover -s tests -v`
Expected: FAIL because `analyse.R` is empty and `make_graph.R` reads the wrong CSV and does not save a file.

**Step 3: Write minimal implementation**
```r
# analyse.R
suppressPackageStartupMessages(library(tidyverse))
args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
out_dir <- if (length(args) >= 2) args[[2]] else "outputs"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
paulgp <- read_csv(input_csv, col_names = c("year", "cites", "paper"), show_col_types = FALSE)

paper_totals <- paulgp %>% filter(paper != "total") %>% group_by(paper) %>% summarise(total_cites = sum(cites), .groups = "drop")
hindex_time <- paulgp %>%
  filter(paper != "total") %>%
  filter(year < max(year)) %>%
  arrange(paper, year) %>%
  group_by(paper) %>%
  mutate(cumulative_cites = cumsum(cites)) %>%
  ungroup() %>%
  group_by(year) %>%
  summarise(hindex = max(which(sort(cumulative_cites, decreasing = TRUE) >= seq_along(cumulative_cites))), .groups = "drop")
summary_tbl <- tibble(
  metric = c("paper_count", "total_citations", "mean_current_cites", "median_current_cites"),
  value = c(n_distinct(paper_totals$paper), sum(paper_totals$total_cites), mean(paper_totals$total_cites), median(paper_totals$total_cites))
)
write_csv(summary_tbl, file.path(out_dir, "paulgp_summary.csv"))
write_csv(hindex_time, file.path(out_dir, "paulgp_hindex.csv"))
write_csv(arrange(paper_totals, desc(total_cites)), file.path(out_dir, "paulgp_top_papers.csv"))
```

```r
# make_graph.R
suppressPackageStartupMessages(library(tidyverse))
args <- commandArgs(trailingOnly = TRUE)
input_csv <- if (length(args) >= 1) args[[1]] else "paulgp_time_series.csv"
output_png <- if (length(args) >= 2) args[[2]] else "outputs/paulgp_citation_share.png"
dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)
time_series <- read_csv(input_csv, col_names = c("year", "cites", "paper"), show_col_types = FALSE)
# reuse current share logic, but point it at Paul data and save with ggsave(...)
```

**Step 4: Run test to verify it passes**
Run: `python3 -m unittest discover -s tests -v`
Expected: PASS for both R smoke tests.

**Step 5: Commit**
```bash
git add analyse.R make_graph.R tests/test_scholar_pipeline.py
git commit -m "feat: add non-interactive analysis outputs"
```

### Task 5: Update documentation and verification commands

**Files:**
- Modify: `README.md`
- Test: manual command copy/paste from README

**Step 1: Write the failing test**
Manual doc test: follow README commands exactly in a clean shell.

**Step 2: Run test to verify it fails**
Run the documented commands as currently written.
Expected: FAIL because README does not mention env vars, script arguments, or output files.

**Step 3: Write minimal implementation**
```markdown
## Setup
export SERPAPI_API_KEY=...

## Refresh Paul data
python3 pull_data.py --author-id ldL9aVEAAAAJ --output paulgp_time_series.csv

## Run analysis
Rscript analyse.R paulgp_time_series.csv outputs
Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png

## Run tests
python3 -m unittest discover -s tests -v
```

**Step 4: Run doc commands to verify they work**
Run the commands exactly as documented.
Expected: all commands succeed and output files are created.

**Step 5: Commit**
```bash
git add README.md
git commit -m "docs: add runnable pipeline instructions"
```

### Task 6: Refresh `paulgp_time_series.csv` and verify the full pipeline

**Files:**
- Modify: `paulgp_time_series.csv`
- Create: `outputs/paulgp_summary.csv`
- Create: `outputs/paulgp_hindex.csv`
- Create: `outputs/paulgp_top_papers.csv`
- Create: `outputs/paulgp_citation_share.png`

**Step 1: Refresh the live data file**
Run:
```bash
export SERPAPI_API_KEY=...
python3 pull_data.py --author-id ldL9aVEAAAAJ --output paulgp_time_series.csv
```
Expected: `paulgp_time_series.csv` updated through the current Scholar year series.

**Step 2: Run the analysis outputs**
Run:
```bash
Rscript analyse.R paulgp_time_series.csv outputs
Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png
```
Expected: CSV summaries and PNG graph are written under `outputs/`.

**Step 3: Run the test suite**
Run:
```bash
python3 -m unittest discover -s tests -v
```
Expected: PASS.

**Step 4: Run final verification commands**
Run:
```bash
python3 pull_data.py --author-id ldL9aVEAAAAJ --output /tmp/paulgp_time_series.verify.csv
Rscript analyse.R /tmp/paulgp_time_series.verify.csv /tmp/paulgp_outputs
Rscript make_graph.R /tmp/paulgp_time_series.verify.csv /tmp/paulgp_outputs/paulgp_citation_share.png
ls -l /tmp/paulgp_outputs
```
Expected: fresh fetch succeeds, analysis succeeds, graph exists, and `/tmp/paulgp_outputs` contains the expected files.

**Step 5: Commit**
```bash
git add paulgp_time_series.csv outputs
git commit -m "data: refresh paul gp scholar outputs"
```