# google_scholar_share

Pull Google Scholar citation time-series data for any author and generate a two-panel graph showing total citations and per-paper share over time.

## Setup

Set your SerpAPI key (get one at <https://serpapi.com/>):

```bash
echo 'SERPAPI_API_KEY=your_key_here' > .env
```

That's it. Scripts use [uv](https://docs.astral.sh/uv/) with inline PEP 723 dependencies, so no manual install step is needed.

## Pull data for an author

Find the author's Google Scholar ID from their profile URL (`user=XXXX`), then:

```bash
uv run pull_data.py --author-id ldL9aVEAAAAJ --output paulgp_time_series.csv
```

## Generate the graph

```bash
Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png
```

Requires R with `tidyverse` and `patchwork` packages.

## Example: multiple authors

```bash
# Paul Goldsmith-Pinkham
uv run pull_data.py --author-id ldL9aVEAAAAJ --output paulgp_time_series.csv
Rscript make_graph.R paulgp_time_series.csv outputs/paulgp_citation_share.png

# Isaac Sorkin
uv run pull_data.py --author-id H9pBCR0AAAAJ --output sorkin_time_series.csv
Rscript make_graph.R sorkin_time_series.csv outputs/sorkin_citation_share.png
```

## Run tests

```bash
uv run -m unittest discover -s tests -v
```
