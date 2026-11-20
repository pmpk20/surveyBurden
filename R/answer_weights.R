#' Validate independent answer distributions, retaining raw answer values.
#' @noRd
normalise_answer_weights <- function(answer_weights, qsf, ctx, field_domains = NULL) {
  if (is.null(answer_weights) || (is.list(answer_weights) && !length(answer_weights))) return(NULL)
  nm <- names(answer_weights)
  if (!is.list(answer_weights) || is.data.frame(answer_weights) || is.null(nm) ||
      anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm)) {
    cli::cli_abort("{.arg answer_weights} must be a named list of independent per-question or stored-field weight vectors.")
  }
  if (any(startsWith(nm, "@?")) || any(startsWith(nm, "@@"))) {
    cli::cli_abort("{.arg answer_weights} requires question IDs or stored-field names; internal free gates and loop-count keys are not supported. Use {.arg loop_weights} for loop counts.")
  }
  vars <- unique(unlist(lapply(ctx$parsed, `[[`, "vars")))
  field_names <- c(vars[startsWith(vars, "@")], paste0("@", names(field_domains)))
  nodes <- qsf_flow(qsf)[["Flow"]]
  field_names <- c(field_names, paste0("@", branch_fields(nodes)))
  flow_walk(nodes, function(node) {
    if (identical(node$Type, "EmbeddedData")) {
      field_names <<- c(field_names, vapply(node$EmbeddedData %||% list(), function(e) {
        paste0("@", e$Field %||% "")
      }, character(1)))
    }
  })
  unknown <- setdiff(nm, c(names(ctx$choices), field_names))
  if (length(unknown)) {
    cli::cli_abort("Unknown question or stored field in {.arg answer_weights}: {.val {unknown}}.")
  }
  conflict <- intersect(nm, names(ctx$rules))
  if (length(conflict)) {
    cli::cli_abort("{.arg answer_weights} and {.arg field_rules} both set {.val {conflict}}.")
  }
  out <- lapply(nm, function(variable) {
    w <- answer_weights[[variable]]
    labels <- names(w)
    if (!is.numeric(w) || is.complex(w) || !is.null(dim(w)) || !length(w) ||
        is.null(labels) || anyNA(labels) || anyDuplicated(labels) ||
        anyNA(w) || any(!is.finite(w)) || any(w < 0) || !any(w > 0)) {
      cli::cli_abort("{.arg answer_weights} entry {.val {variable}} must be a named numeric vector of finite, non-negative weights with positive total mass and unique state names.")
    }
    if (!startsWith(variable, "@")) {
      type <- ctx$stype[[variable]]
      if (!type %in% c("single_choice", "multi_choice")) {
        cli::cli_abort("{.arg answer_weights} supports single-choice and multi-select questions; {.val {variable}} has type {.val {type}}. Use a stored-field comparison for a numeric entry.")
      }
      choices <- ctx$choices[[variable]]
      selections <- lapply(labels, function(label) {
        if (!nzchar(label)) return(character(0))
        strsplit(label, "+", fixed = TRUE)[[1L]]
      })
      invalid <- vapply(seq_along(selections), function(i) {
        s <- selections[[i]]
        (nzchar(labels[i]) && (startsWith(labels[i], "+") || endsWith(labels[i], "+"))) ||
          any(!nzchar(s)) || anyDuplicated(s) > 0L || any(!s %in% choices) ||
          (identical(type, "single_choice") && length(s) > 1L)
      }, logical(1))
      if (any(invalid)) {
        cli::cli_abort("Invalid choice or subset state for {.val {variable}} in {.arg answer_weights}: {.val {labels[invalid]}}. Use QSF choice IDs; join a multi-select subset with {.val +}.")
      }
      labels <- vapply(selections, function(s) paste(sort(s), collapse = "+"), character(1))
      if (anyDuplicated(labels)) {
        cli::cli_abort("Duplicate subset states for {.val {variable}} in {.arg answer_weights} after canonical ordering.")
      }
      if (variable %in% ctx$forced && any(w[labels == ""] > 0)) {
        cli::cli_abort("Forced-response question {.val {variable}} cannot have positive unanswered weight in {.arg answer_weights}; set {.arg respect_force_response = FALSE} to override this assumption.")
      }
    } else {
      domain <- field_domains[[substring(variable, 2L)]]
      if (!is.null(domain)) {
        domain <- as.character(domain)
        domain[is.na(domain)] <- ""
        if (any(!labels[w > 0] %in% domain)) {
          cli::cli_abort("{.arg answer_weights} for {.val {variable}} assigns positive weight outside {.arg field_domains}.")
        }
      }
    }
    # Scaling first avoids overflow for finite weights such as c(1e308, 1e308).
    w <- as.numeric(w) / max(w)
    w <- w / sum(w)
    stats::setNames(w, labels)
  })
  stats::setNames(out, nm)
}
