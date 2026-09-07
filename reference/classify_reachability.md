# Partition a set of catalogue rows into always / maybe / unreachable

Partition a set of catalogue rows into always / maybe / unreachable

## Usage

``` r
classify_reachability(catalogue, path_qids)
```

## Arguments

- catalogue:

  Catalogue rows (needs `question_id`, `has_display_logic`,
  `display_logic_refs`).

- path_qids:

  Character vector of every question id on the path.

## Value

A list with character vectors `always`, `maybe`, `unreachable`.
