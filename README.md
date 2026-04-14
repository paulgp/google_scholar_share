# google_scholar_share

Simple scripts to pull Google Scholar citation time-series data from an author's profile and generate analysis outputs.

## Setup

Create a virtual environment and install the Python dependency:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Set your SerpAPI key:

```bash
export SERPAPI_API_KEY=your_serpapi_key_here
```

You can get a key from <https://serpapi.com/>.

## Refresh Paul Goldsmith-Pinkham data

```bash
.venv/bin/python pull_data.py --author-id ldL9aVEAAAAJ --output paulgp_time_series.csv
```

## Generate analysis outputs

```bash
Rscript analyse.R paulgp_time_series.csv outputs
Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png
```

This writes:
- `outputs/paulgp_summary.csv`
- `outputs/paulgp_hindex.csv`
- `outputs/paulgp_top_papers.csv`
- `outputs/paulgp_citation_share.png`

## Run tests

```bash
.venv/bin/python -m unittest discover -s tests -v
```
