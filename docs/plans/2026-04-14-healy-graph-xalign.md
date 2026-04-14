# Healy Graph X-Axis Alignment Implementation Plan

**Goal:** Align the x-axis domain of the top and bottom graph panels so the panels share the same horizontal scale.
**Architecture:** Keep `make_graph.R` as the graph entrypoint, but compute one shared x-range and apply it to both panels. Add a regression test that makes the shared range explicit via stdout metadata so x-axis alignment is testable.
**Tech Stack:** R (`tidyverse`, `grid`), Python `unittest`, PNG output.

- [x] Task 1: Add a failing test for shared x-range metadata ✅
- [x] Task 2: Refactor `make_graph.R` to use one shared x-axis range across panels ✅
- [x] Task 3: Regenerate the graph and verify the full suite ✅
