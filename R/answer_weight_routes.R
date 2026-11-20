#' Route components under assumed marginal answer frequencies
#'
#' Integrate weighted flow variables once, before distinct block sequences are
#' deduplicated. Residual, unspecified branches and randomisers retain the
#' package's equal-distinct-route convention within each weighted assignment;
#' these are structural model weights, not probabilities inferred from the QSF.
#' @noRd
answer_weight_routes <- function(qsf, ctx, paths, sel, weights,
                                 field_domains = NULL, max_paths = 10000L) {
  nodes <- qsf_flow(qsf)$Flow
  raw_variables <- function(tree) {
    if (!is.list(tree)) return(character(0))
    if (identical(tree$LogicType, "EmbeddedField")) {
      return(paste0("@", tree$LeftOperand %||% ""))
    }
    if (identical(tree$LogicType %||% "", "Question") ||
        (!is.null(tree$QuestionID) && is.null(tree$LogicType)) ||
        (is.character(tree$LeftOperand) && startsWith(tree$LeftOperand, "q://") &&
         is.null(tree$LogicType))) {
      return(tree$QuestionID %||%
        sub("^q://(QID[0-9]+).*", "\\1", tree$LeftOperand %||% ""))
    }
    unique(unlist(lapply(tree, raw_variables), use.names = FALSE))
  }
  flow_vars <- character(0)
  assigned <- character(0)
  flow_walk(nodes, function(node) {
    if (identical(node$Type, "Branch")) {
      flow_vars <<- union(flow_vars, union(parse_display_logic(node$BranchLogic)$vars,
                                          raw_variables(node$BranchLogic)))
    }
    if (identical(node$Type, "EmbeddedData")) {
      assigned <<- union(assigned, vapply(node$EmbeddedData %||% list(),
        function(entry) paste0("@", entry$Field %||% ""), character(1)))
    }
  })
  relevant <- intersect(names(weights), union(flow_vars, assigned))
  if (!length(relevant)) {
    return(lapply(sel, function(i) list(path_index = i,
      mass = 1 / nrow(paths), fixed = list())))
  }
  weights <- lapply(weights, function(weight) weight[weight > 0])
  counts <- vapply(weights[relevant], length, integer(1))
  if (sum(log(counts)) > log(1e5) + 1e-10) {
    cli::cli_abort("{.arg answer_weights} needs more than 100000 weighted flow assignments; reduce its routing support.")
  }
  grid <- expand.grid(lapply(weights[relevant], names), stringsAsFactors = FALSE,
                      KEEP.OUT.ATTRS = FALSE)
  path_key <- function(ids, early) paste(paste(ids, collapse = "\r"), early, sep = "\n")
  original_keys <- vapply(seq_len(nrow(paths)), function(i)
    path_key(paths$block_ids[[i]], paths$terminates_early[i]), character(1))
  stopifnot(!anyDuplicated(original_keys))
  fail <- function(detail) cli::cli_abort(c(
    "Unsupported flow logic for {.arg answer_weights}: {detail}.",
    i = "Weighted routing currently requires earlier unconditional non-loop question triggers, fully specified branch predicates, and constant stored-field assignments before any block."))
  components <- list()
  for (row in seq_len(nrow(grid))) {
    fixed <- as.list(grid[row, , drop = FALSE])
    state <- lapply(names(fixed), function(name) {
      value <- fixed[[name]]
      if (startsWith(name, "@")) {
        if (identical(value, "")) NA_character_ else value
      } else if (identical(value, "")) character(0) else strsplit(value, "+", fixed = TRUE)[[1L]]
    })
    names(state) <- names(fixed)
    probability <- prod(vapply(relevant, function(name)
      unname(weights[[name]][match(fixed[[name]], names(weights[[name]]))]), numeric(1)))
    if (probability <= 0) next
    # State is carried through deterministic flow only. Unknown control flow
    # cannot change a weighted field, or make a later trigger certainly shown.
    simplify <- function(flow, current, current_fixed, seen = character(0),
                         passed_block = FALSE, uncertain = FALSE) {
      out <- list()
      for (node in flow) {
        type <- node$Type %||% ""
        if (type %in% c("Standard", "Block")) {
          block <- node$ID %||% ""
          index <- match(block, ctx$blocks$block_id)
          if (!is.na(index)) {
            questions <- ctx$blocks$question_ids[[index]]
            if (is.na(ctx$loop_max[[block]])) {
              seen <- union(seen, setdiff(questions, names(ctx$parsed)))
            }
          }
          passed_block <- TRUE
        }
        if (identical(type, "EmbeddedData")) {
          for (entry in node$EmbeddedData %||% list()) {
            name <- paste0("@", entry$Field %||% "")
            if (!name %in% relevant) next
            value <- entry$Value %||% ""
            assignment <- nzchar(value) || identical(entry$Type, "Custom")
            if (!assignment) next
            if (!is.character(value) || length(value) != 1L ||
                grepl("\\$[A-Za-z]*\\{", value)) fail("a weighted stored field has a computed or piped assignment")
            if (uncertain) fail("a weighted stored field is assigned inside unspecified branching or a randomiser")
            if (passed_block) fail("a weighted stored field is reassigned after a block")
            current[name] <- list(if (nzchar(value)) value else NA_character_)
            current_fixed[name] <- list(value)
          }
        }
        if (identical(type, "Branch")) {
          parsed <- parse_display_logic(node$BranchLogic)
          affected <- intersect(union(parsed$vars, raw_variables(node$BranchLogic)), relevant)
          if (length(affected)) {
            if (!all(parsed$vars %in% relevant)) fail("a branch mixes weighted and unspecified variables or uses an unsupported operator")
            if (length(parsed$displayed) || length(parsed$loop_blocks) ||
                any(startsWith(parsed$vars, "@?")) ||
                any(startsWith(parsed$vars, "@q://"))) fail("a weighted branch uses displayed, loop, free, or piped conditions")
            fields <- parsed$vars[startsWith(parsed$vars, "@")]
            if (any(!fields %in% names(parsed$fields))) fail("a weighted stored-field branch uses an unsupported comparison")
            questions <- setdiff(parsed$vars, fields)
            if (any(!questions %in% seen)) fail("a weighted question is conditional, inside a loop, or not shown before its branch")
            # Supported question predicates must be selection tests. Other
            # operators are represented as free gates by the parser above.
            take <- parsed$predicate(current)
            if (isTRUE(take)) {
              child <- simplify(node$Flow %||% list(), current, current_fixed,
                                seen, passed_block, uncertain)
              out <- c(out, child$flow)
              current <- child$state; current_fixed <- child$fixed
              seen <- child$seen; passed_block <- child$passed_block
            }
            next
          }
          child <- simplify(node$Flow %||% list(), current, current_fixed,
                            seen, passed_block, TRUE)
          node$Flow <- child$flow
          # Both unknown outcomes remain feasible, so child state/seen are
          # deliberately not propagated to the continuation.
          if (flow_has_blocks(node$Flow)) passed_block <- TRUE
        } else if (is.list(node$Flow)) {
          random <- identical(type, "BlockRandomizer")
          child <- simplify(node$Flow, current, current_fixed, seen,
                            passed_block, uncertain || random)
          node$Flow <- child$flow
          if (!random) {
            current <- child$state; current_fixed <- child$fixed
            seen <- child$seen; passed_block <- child$passed_block
          } else if (flow_has_blocks(node$Flow)) passed_block <- TRUE
        }
        out[[length(out) + 1L]] <- node
        if (identical(type, "EndSurvey")) break
      }
      list(flow = out, state = current, fixed = current_fixed,
           seen = seen, passed_block = passed_block)
    }
    simplified <- simplify(nodes, state, fixed)
    candidates <- enumerate_paths(simplified$flow, max_paths = max_paths,
      field_domains = validate_field_domains(field_domains))
    keys <- vapply(seq_len(nrow(candidates)), function(i)
      path_key(candidates$block_ids[[i]], candidates$terminates_early[i]), character(1))
    matches <- match(keys, original_keys)
    if (anyNA(matches)) fail("a weighted assignment produces a route absent from the original structural space")
    for (i in seq_along(matches)) {
      if (!matches[i] %in% sel) next
      components[[length(components) + 1L]] <- list(path_index = matches[i],
        mass = probability / nrow(candidates), fixed = simplified$fixed)
    }
    if (length(components) > 1e5) {
      cli::cli_abort("{.arg answer_weights} produces more than 100000 route components; reduce its routing support.")
    }
  }
  components
}
