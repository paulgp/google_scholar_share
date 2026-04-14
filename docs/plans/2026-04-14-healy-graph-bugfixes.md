# Healy Graph Bugfixes Implementation Plan

**Goal:** Make the bottom composition panel sum to 100% and align label connector lines with the actual stacked areas.
**Architecture:** Keep `make_graph.R` as the single graph entrypoint, but change the composition calculation to build residual shares from the aggregate total minus selected papers, and compute label anchors using the same stack direction the area chart renders. Add regression tests for exact 100% composition and correct top-to-bottom label order.
**Tech Stack:** R (`tidyverse`, `grid`), Python `unittest`, PNG graph output.

- [x] Task 1: Add failing tests for normalized composition and correct label order ✅
- [x] Task 2: Refactor `make_graph.R` composition and label-anchor logic ✅
- [x] Task 3: Regenerate the graph and verify the full suite ✅
