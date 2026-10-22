#' Enumerate the structural paths through the survey flow
#'
#' Walks the `SurveyFlow`, forking at every `Branch` into feasible outcomes.
#' When consecutive branches each test the same embedded-data field with one
#' comparison (`=`, `!=`, `>`, `>=`, `<`, `<=`), they are evaluated jointly:
#' only combinations of outcomes that some value of the field can produce are
#' enumerated. Equality tests against different values become one-of-k plus a
#' "none matches" fallback; complementary tests such as `> 0` and `= 0` can no
#' longer both be taken. All other branches are still forked into a
#' condition-true and a condition-false path. The result is the *structural
#' path space* -- every block sequence a respondent could encounter -- without
#' any assumption about branch probabilities.
#'
#' A field holds one value along a path, so every branch on it agrees with
#' that value, whether or not the branches are adjacent. A fixed value set in
#' the flow (an embedded-data assignment, including one chosen by a block
#' randomiser) decides the branches after it, until the field is set again;
#' a piped or computed value (`${...}`) makes it unknown again.
#'
#' Otherwise field values are unrestricted: a field may hold any value or be
#' empty, so an outcome such as "neither `> 0` nor `= 0`" (a negative or
#' empty field) is kept, and a run of equality tests keeps a "none matches"
#' path. The enumeration is therefore an upper bound under unrestricted field
#' values. When a field can only hold certain values (for example a panel
#' field coded 0 to 5), declare them in `field_domains` to drop the paths no
#' declared value can produce. Where a survey's own code limits a field's
#' values (for example, question JavaScript that always writes a count), some
#' enumerated paths may be impossible in practice. `resolve_flow()` reports branch fields it finds
#' assigned in question JavaScript, so these cases can be checked; it does not
#' interpret the code, and it may not detect every assignment.
#'
#' Within-block display logic (whether an individual question is shown) is *not*
#' resolved here; that is a separate step. Paths are at block granularity.
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param max_paths Cap on the number of distinct paths. If the flow would
#'   produce more, an error is raised rather than a partial result.
#' @param field_domains Optional named list giving, for an embedded-data
#'   field, every value it can hold, e.g. `list(SP_05 = 0:5)` (values are
#'   compared as text or numbers like Qualtrics does; `NA` stands for an
#'   empty field). Branches on a declared field are enumerated only for those
#'   values. A value set in the flow still takes precedence. Naming a field
#'   no branch tests gives a warning.
#'
#' @return A [tibble][tibble::tibble], one row per distinct path:
#'   \describe{
#'     \item{path_id}{Integer id.}
#'     \item{block_ids}{List column: ordered `BL_...` ids the path shows.}
#'     \item{terminates_early}{`TRUE` if the path hits an `EndSurvey` before the
#'       end of the flow (a screen-out or quota termination).}
#'     \item{decisions}{List column: named logical vector, one entry per branch
#'       on one combination of branch outcomes that produces this path, `TRUE` =
#'       condition taken.}
#'   }
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' flow <- resolve_flow(read_qsf(qsf_path))
#' flow[, c("path_id", "terminates_early")]
#' \dontrun{
#' resolve_flow(read_qsf("survey.qsf"), field_domains = list(group = c("1", "2")))
#' }
#'
#' @export
resolve_flow <- function(qsf, max_paths = 10000L, field_domains = NULL) {
  if (!inherits(qsf, "qsf_raw")) {
    cli::cli_abort("{.arg qsf} must be a {.cls qsf_raw} object from {.fn read_qsf}.")
  }
  field_domains <- validate_field_domains(field_domains)
  nodes <- qsf_flow(qsf)[["Flow"]]
  unused <- setdiff(names(field_domains), branch_fields(nodes))
  if (length(unused)) {
    cli::cli_warn("{.arg field_domains} names {cli::qty(length(unused))}{?a field/fields} no branch tests, so {?it is/they are} ignored: {.val {unused}}.")
  }
  js <- js_assigned_branch_fields(qsf, nodes)
  if (nrow(js)) {
    where <- paste(sprintf("%s (%s)", js$field, js$questions), collapse = "; ")
    cli::cli_inform(c(
      i = paste("Branch field(s) assigned in question JavaScript: {where}.",
                "Their possible values were not inferred; enumerated paths may",
                "include outcomes excluded by that code.")
    ))
  }
  enumerate_paths(nodes, max_paths = max_paths, field_domains = field_domains)
}

#' Check `field_domains`: `NULL`, or a named list of non-empty vectors of
#' values (converted to text; `NA` stands for an empty field).
#' @noRd
validate_field_domains <- function(field_domains) {
  if (is.null(field_domains)) return(list())
  nm <- names(field_domains)
  if (!is.list(field_domains) || is.null(nm) || any(!nzchar(nm)) || anyDuplicated(nm)) {
    cli::cli_abort(c(
      "{.arg field_domains} must be a named list, one element per embedded field.",
      i = "For example {.code list(SP_05 = 0:5)}."
    ))
  }
  bad <- nm[vapply(field_domains, function(v) !is.atomic(v) || length(v) == 0L, logical(1))]
  if (length(bad)) {
    cli::cli_abort("{.arg field_domains} must give at least one value for each field; check {.val {bad}}.")
  }
  lapply(field_domains, function(v) unique(as.character(v)))
}

#' Embedded-data fields tested by any branch in the flow
#' @noRd
branch_fields <- function(nodes) {
  out <- character(0)
  grab <- function(x) {
    if (!is.list(x)) return(invisible())
    if (identical(x[["LogicType"]], "EmbeddedField") && is.character(x[["LeftOperand"]])) {
      out <<- c(out, x[["LeftOperand"]])
    }
    for (el in x) if (is.list(el)) grab(el)
  }
  flow_walk(nodes, function(n) if (identical(n$Type, "Branch")) grab(n[["BranchLogic"]]))
  unique(out)
}

#' Branch fields that question JavaScript assigns with
#' `setEmbeddedData("<field>", ...)`: a data frame of each field and the
#' questions that assign it. Detection is textual. It finds literal field
#' names only, and does not establish that the code runs or what it writes.
#' @noRd
js_assigned_branch_fields <- function(qsf, nodes) {
  empty <- data.frame(field = character(0), questions = character(0))
  fields <- branch_fields(nodes)
  if (!length(fields)) return(empty)
  pat <- "setEmbeddedData\\(\\s*[\"']([^\"']+)[\"']"
  hits <- list()
  for (el in qsf$SurveyElements) {
    js <- el$Payload$QuestionJS
    if (!identical(el$Element, "SQ") || !is.character(js) || !nzchar(js)) next
    m <- regmatches(js, gregexpr(pat, js))[[1]]
    f <- unique(sub(paste0("^", pat, "$"), "\\1", m))
    for (x in intersect(f, fields)) hits[[length(hits) + 1L]] <- c(x, el$PrimaryAttribute %||% "?")
  }
  if (!length(hits)) return(empty)
  h <- as.data.frame(do.call(rbind, hits), stringsAsFactors = FALSE)
  names(h) <- c("field", "question")
  agg <- tapply(h$question, h$field, function(q) paste(unique(q), collapse = ", "))
  data.frame(field = names(agg), questions = unname(agg))
}

#' Comparison operators that can be evaluated jointly on one field
#' @noRd
branch_ops <- c("EqualTo", "NotEqualTo", "GreaterThan", "GreaterThanOrEqual",
                "LessThan", "LessThanOrEqual")

#' Extract the grouping key from a Branch node, if it is a simple single-literal
#' EmbeddedField comparison. Returns `list(field, op, value)` or NULL.
#' @noRd
extract_branch_key <- function(node) {
  bl <- node[["BranchLogic"]]
  if (!is.list(bl)) return(NULL)
  group_keys <- setdiff(names(bl), c("Type", "inPage"))
  if (length(group_keys) != 1L) return(NULL)
  g <- bl[[group_keys[1]]]
  lit_keys <- setdiff(names(g), "Type")
  if (length(lit_keys) != 1L) return(NULL)
  lit <- g[[lit_keys[1]]]
  if (!identical(lit[["LogicType"]] %||% "", "EmbeddedField")) return(NULL)
  op <- lit[["Operator"]] %||% ""
  if (!op %in% branch_ops) return(NULL)
  field <- lit[["LeftOperand"]] %||% ""
  if (nchar(field) == 0L) return(NULL)
  list(field = field, op = op, value = as.character(lit[["RightOperand"]] %||% ""))
}

#' Evaluate one Qualtrics comparison. `x` is a candidate field value
#' (NA = empty). Numeric when both sides parse as numbers, else string.
#' @noRd
eval_branch_op <- function(op, x, rhs) {
  if (is.na(x)) return(identical(op, "NotEqualTo"))
  xn <- suppressWarnings(as.numeric(x)); rn <- suppressWarnings(as.numeric(rhs))
  num <- !is.na(xn) && !is.na(rn)
  switch(op,
    EqualTo            = if (num) xn == rn else identical(as.character(x), rhs),
    NotEqualTo         = if (num) xn != rn else !identical(as.character(x), rhs),
    GreaterThan        = num && xn >  rn,
    GreaterThanOrEqual = num && xn >= rn,
    LessThan           = num && xn <  rn,
    LessThanOrEqual    = num && xn <= rn,
    FALSE)
}

#' The distinct outcome vectors (one logical per comparison) that some value
#' of the field can produce.
#' @noRd
feasible_outcomes <- function(ops, values) {
  lapply(field_value_classes(ops, values), function(x) field_outcome(ops, values, x))
}

#' One representative value per distinguishable class of a field compared by
#' `ops` against `values`: two values are in the same class when every
#' comparison gives the same result for both. Candidate values cover every
#' region the thresholds define, each tested string, an unmatched string, and
#' an empty field (`NA`). Returns a character vector.
#' @noRd
field_value_classes <- function(ops, values) {
  nums <- suppressWarnings(as.numeric(values))
  nums <- sort(unique(nums[!is.na(nums)]))
  mids <- if (length(nums) > 1L) (utils::head(nums, -1) + utils::tail(nums, -1)) / 2 else numeric(0)
  cand <- c(as.character(c(nums, mids, if (length(nums)) c(min(nums) - 1, max(nums) + 1))),
            unique(values), "other", NA)
  keys <- vapply(cand, function(x) paste(field_outcome(ops, values, x), collapse = ""),
                 character(1))
  cand[!duplicated(keys)]
}

#' Results of each comparison for one candidate field value.
#' @noRd
field_outcome <- function(ops, values, x) {
  vapply(seq_along(ops), function(i) eval_branch_op(ops[[i]], x, values[[i]]), logical(1))
}

#' Does a flow (list of nodes) show any block, at any depth?
#' @noRd
flow_has_blocks <- function(nodes) {
  for (n in nodes) {
    if (!is.list(n)) next
    if ((n[["Type"]] %||% "") %in% c("Standard", "Block")) return(TRUE)
    if (is.list(n[["Flow"]]) && flow_has_blocks(n[["Flow"]])) return(TRUE)
  }
  FALSE
}

#' Replace runs of consecutive Branch nodes on one field with a single
#' synthetic ExclusiveBranchGroup node. A run qualifies when every Branch in
#' it is a simple single-literal EmbeddedField comparison on the same field;
#' a single such Branch becomes a group of one, so its field's value is
#' tracked along the path.
#' Recurses into Group, Authenticator, and BlockRandomizer child flows.
#' @noRd
collapse_exclusive_branches <- function(nodes) {
  if (length(nodes) == 0L) return(nodes)
  # Recurse into container nodes first
  nodes <- lapply(nodes, function(n) {
    tp <- n[["Type"]] %||% ""
    if (tp %in% c("Group", "Authenticator", "BlockRandomizer", "Branch") &&
        is.list(n[["Flow"]])) {
      n[["Flow"]] <- collapse_exclusive_branches(n[["Flow"]])
    }
    n
  })
  out <- list()
  i <- 1L
  while (i <= length(nodes)) {
    node <- nodes[[i]]
    if (!identical(node[["Type"]] %||% "", "Branch")) {
      out[[length(out) + 1L]] <- node
      i <- i + 1L
      next
    }
    key <- extract_branch_key(node)
    if (is.null(key)) {
      out[[length(out) + 1L]] <- node
      i <- i + 1L
      next
    }
    run <- list(node)
    j <- i + 1L
    while (j <= length(nodes) &&
           identical(nodes[[j]][["Type"]] %||% "", "Branch")) {
      k2 <- extract_branch_key(nodes[[j]])
      if (is.null(k2) || !identical(k2$field, key$field)) break
      run[[length(run) + 1L]] <- nodes[[j]]
      j <- j + 1L
    }
    if (length(run) >= 1L) {
      fids <- vapply(run, function(b) b[["FlowID"]] %||% "branch", character(1))
      keys <- lapply(run, extract_branch_key)
      out[[length(out) + 1L]] <- list(
        Type     = "ExclusiveBranchGroup",
        branches = run,
        field    = key$field,
        ops      = vapply(keys, `[[`, "", "op"),
        values   = vapply(keys, `[[`, "", "value"),
        FlowID   = paste0("XG:", paste(fids, collapse = "+"))
      )
    } else {
      out[[length(out) + 1L]] <- node
    }
    i <- j
  }
  out
}

#' Enumerate paths from a bare list of flow nodes. Internal; see [resolve_flow()].
#'
#' Uses a memoised set-of-outcomes recursion: `outcomes(remaining)` is the set of
#' `(future block sequence, terminated early)` pairs reachable from a flow
#' position, independent of what came before. Memoising on the remaining-node
#' sequence collapses the branch explosion (many branches only set embedded data
#' and do not change the block sequence).
#' @noRd
enumerate_paths <- function(nodes, max_paths = 10000L, field_domains = list()) {
  nodes <- collapse_exclusive_branches(nodes)
  exclusive_fields <- character(0)
  joint_notes <- character(0)

  # Each tracked field (one tested by a simple branch) holds one value along a
  # path. Its candidate values are one per class of all its comparisons in
  # the flow, or its declared domain. `st` maps fields to their value on the
  # current path (NA = empty); a field not in `st` is not yet decided.
  cmp <- list()
  collect <- function(ns) for (n in ns) {
    if (!is.list(n)) next
    if (identical(n$Type, "ExclusiveBranchGroup")) {
      cmp[[n$field]] <<- rbind(cmp[[n$field]], cbind(n$ops, n$values))
      for (b in n$branches) collect(b[["Flow"]])
    } else if (is.list(n[["Flow"]])) {
      collect(n[["Flow"]])
    }
  }
  collect(nodes)
  tracked <- names(cmp)
  classes <- lapply(stats::setNames(tracked, tracked), function(f) {
    ops <- cmp[[f]][, 1]; values <- cmp[[f]][, 2]
    cand <- field_domains[[f]] %||% field_value_classes(ops, values)
    keys <- vapply(cand, function(x) paste(field_outcome(ops, values, x), collapse = ""),
                   character(1))
    cand[!duplicated(keys)]
  })
  state_key <- function(st) {
    if (!length(st)) return("")
    st <- st[order(names(st))]
    v <- unlist(st)
    paste(names(st), ifelse(is.na(v), "\001NA", v), sep = "=", collapse = "\002")
  }
  # tracked fields an EmbeddedData node sets: a fixed value (a Custom
  # assignment, including an empty one) sets it; a piped or computed value
  # makes it unknown again; a declaration with no value (a panel or URL
  # field) changes nothing
  assign_fields <- function(node, st) {
    for (e in node$EmbeddedData %||% list()) {
      f <- e$Field %||% ""
      if (!f %in% tracked) next
      val <- e$Value %||% ""
      if (!is.character(val) || grepl("\\$[A-Za-z]*\\{", val)) {
        st[[f]] <- NULL
      } else if (nzchar(val) || identical(e$Type, "Custom")) {
        st[f] <- list(if (nzchar(val)) val else NA_character_)
      }
    }
    st
  }
  assigns_tracked <- function(children) {
    hit <- FALSE
    flow_walk(children, function(n) if (identical(n$Type, "EmbeddedData")) {
      if (any(vapply(n$EmbeddedData %||% list(), function(e) (e$Field %||% "") %in% tracked,
                     logical(1)))) hit <<- TRUE
    })
    hit
  }

  memo <- new.env(parent = emptyenv())
  randomisers <- character(0)   # collected, warned about once (see below)
  web_services <- character(0)  # likewise, noted once

  key_of <- function(remaining) {
    paste(vapply(remaining, function(n) n$FlowID %||% n$Type %||% "?", character(1)),
          collapse = ",")
  }
  # Each outcome carries `bkey` == paste(blocks, collapse = ">"), built one
  # block at a time as outcomes are extended, so dedupe never re-collapses a
  # whole block sequence.
  dedupe <- function(outs) {
    keys <- vapply(outs, function(o) paste0(o$bkey, "|", o$early), character(1))
    outs[!duplicated(keys)]
  }
  annotate <- function(outs, fid, value) {
    lapply(outs, function(o) {
      o$decisions <- c(stats::setNames(list(value), fid), o$decisions)
      o
    })
  }

  outcomes <- function(remaining, st = list()) {
    if (length(remaining) == 0L) {
      return(list(list(blocks = character(0), bkey = "", early = FALSE, decisions = list())))
    }
    key <- paste0(key_of(remaining), "#", state_key(st))
    hit <- memo[[key]]
    if (!is.null(hit)) return(hit)

    node <- remaining[[1]]
    rest <- remaining[-1]
    type <- node$Type %||% NA_character_

    res <- if (type %in% c("Standard", "Block")) {
      id <- node$ID %||% NA_character_
      lapply(outcomes(rest, st), function(o) {
        o$bkey <- if (length(o$blocks)) paste0(id, ">", o$bkey) else paste(id)
        o$blocks <- c(id, o$blocks)
        o
      })
    } else if (type == "EmbeddedData") {
      outcomes(rest, assign_fields(node, st))
    } else if (type == "EndSurvey") {
      list(list(blocks = character(0), bkey = "", early = length(rest) > 0L, decisions = list()))
    } else if (type == "ExclusiveBranchGroup") {
      branches <- node$branches
      f <- node$field
      exclusive_fields <<- c(exclusive_fields, f)
      if (length(branches) > 1L) {
        n_feas <- length(unique(lapply(classes[[f]], function(x) field_outcome(node$ops, node$values, x))))
        joint_notes <<- c(joint_notes, sprintf("%s: %d of %d", f, n_feas, 2L^length(branches)))
      }
      # a decided field takes its one outcome; otherwise one fork per value
      xs <- if (f %in% names(st)) st[f] else as.list(classes[[f]])
      all_outs <- list()
      for (x in xs) {
        v <- field_outcome(node$ops, node$values, x)
        st2 <- st
        st2[f] <- list(x)
        # taken branches run in flow order, then the rest of the flow
        sub  <- do.call(c, c(list(list()), lapply(branches[v], function(b) b[["Flow"]] %||% list())))
        outs <- outcomes(c(sub, rest), st2)
        for (bi in rev(seq_along(branches))) {
          outs <- annotate(outs, branches[[bi]][["FlowID"]] %||% "branch", v[[bi]])
        }
        all_outs <- c(all_outs, outs)
      }
      all_outs
    } else if (type == "Branch") {
      fid <- node$FlowID %||% "branch"
      taken <- annotate(outcomes(c(node[["Flow"]] %||% list(), rest), st), fid, TRUE)
      not   <- annotate(outcomes(rest, st), fid, FALSE)
      c(taken, not)   # deduped with every other node type below
    } else if (type %in% c("Group", "Authenticator")) {
      # an Authenticator wraps the flow shown once a respondent authenticates;
      # failed authentication never yields a response, so only that flow counts
      outcomes(c(node[["Flow"]] %||% list(), rest), st)
    } else if (type == "BlockRandomizer") {
      children <- node[["Flow"]] %||% list()
      m <- randomiser_subset(node)
      sets_fields <- assigns_tracked(children)
      if ((!flow_has_blocks(children) && !sets_fields) || (!is.na(m) && m >= length(children))) {
        # a randomiser holding only embedded-data assignments (random condition
        # assignment) shows no blocks, so it cannot change burden; one showing
        # every child shows them all (order does not change burden)
        outcomes(c(children, rest), st)
      } else if (is.na(m) && !flow_has_blocks(children)) {
        # assignments from an unknown subset: the fields they set are unknown
        st2 <- st
        flow_walk(children, function(n) if (identical(n$Type, "EmbeddedData")) {
          for (e in n$EmbeddedData %||% list()) st2[[e$Field %||% ""]] <<- NULL
        })
        outcomes(rest, st2)
      } else if (is.na(m)) {
        randomisers <<- c(randomisers, node$FlowID %||% node$ID %||% "BlockRandomizer")
        outcomes(c(children, rest), st)
      } else {
        # show m of the children: one outcome per combination, survey order
        n_comb <- choose(length(children), m)
        if (n_comb > max_paths) path_space_abort(max_paths, nodes)
        do.call(c, lapply(utils::combn(length(children), m, simplify = FALSE),
                          function(ix) outcomes(c(children[ix], rest), st)))
      }
    } else if (type == "WebService") {
      # a web-service call shows nothing; it can set embedded fields, which
      # branches then treat like any other field (both outcomes enumerated)
      if (length(node$ResponseMap)) {
        web_services <<- c(web_services, node$FlowID %||% "WebService")
      }
      outcomes(rest, st)
    } else {
      cli::cli_warn("Unhandled flow node type {.val {type}}; skipping.")
      outcomes(rest, st)
    }

    res <- dedupe(res)
    if (length(res) > max_paths) path_space_abort(max_paths, nodes)
    memo[[key]] <- res
    res
  }

  paths <- dedupe(outcomes(nodes))

  exclusive_fields <- unique(exclusive_fields)
  if (length(joint_notes)) {
    joint_notes <- paste(unique(joint_notes), collapse = "; ")
    cli::cli_inform(c(
      i = "Branches on the same embedded field evaluated jointly (feasible of 2^k outcomes): {joint_notes}."
    ))
  }

  web_services <- unique(web_services)
  if (length(web_services)) {
    cli::cli_inform(c(
      i = paste("{length(web_services)} web-service call{?s} in the flow set embedded",
                "fields from an external response; branches on those fields are enumerated both ways."),
      i = "Flow node{?s}: {.val {web_services}}"
    ))
  }

  randomisers <- unique(randomisers)
  if (length(randomisers)) {
    cli::cli_warn(c(
      paste("{length(randomisers)} BlockRandomizer{?s} in the flow without a readable",
            "number of elements to show; treating all sub-blocks as shown, in survey order."),
      i = "Affected flow node{?s}: {.val {randomisers}}"
    ))
  }

  tibble::tibble(
    path_id          = seq_along(paths),
    block_ids        = lapply(paths, function(p) p$blocks),
    terminates_early = vapply(paths, function(p) p$early, logical(1)),
    decisions        = lapply(paths, function(p) {
      d <- p$decisions
      if (length(d) == 0L) logical(0) else unlist(d)
    })
  )
}

#' Stop: the path space exceeds `max_paths`.
#' @noRd
path_space_abort <- function(max_paths, nodes) {
  cli::cli_abort(c(
    "This survey's path space is too large to enumerate.",
    i = "More than {max_paths} distinct paths; the flow has {count_branches(nodes)} branches.",
    i = "Raise {.arg max_paths} (e.g. {.code burden_report(x, max_paths = 50000)}) or treat this as a diagnostic finding (intractable routing)."
  ))
}

#' How many of its children a BlockRandomizer shows (`SubSet`, a number or a
#' string); `NA` when missing or not a positive whole number.
#' @noRd
randomiser_subset <- function(node) {
  x <- node[["SubSet"]]
  if (length(x) != 1L) return(NA_integer_)
  m <- suppressWarnings(as.numeric(as.character(x)))
  if (is.na(m) || m < 1 || m != round(m)) return(NA_integer_)
  as.integer(m)
}

#' Count Branch nodes anywhere in a flow-node list
#' @noRd
count_branches <- function(nodes) {
  n <- 0L
  flow_walk(nodes, function(node) if (identical(node$Type, "Branch")) n <<- n + 1L)
  n
}
