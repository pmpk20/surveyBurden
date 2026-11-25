# Internal graph and condition labels for the route flowchart.
flowchart_text <- function(x) {
  trimws(gsub("\\s+", " ", gsub("<[^>]+>", "", x %||% "")))
}

flowchart_lookup <- function(qsf) {
  sq <- qsf_elements(qsf, "SQ")
  stats::setNames(sq, vapply(sq, function(s) s$QuestionID %||% "", ""))
}

describe_branch <- function(node, lookup = list()) {
  literal <- function(it) {
    type <- it$LogicType %||% "unknown"
    op <- it$Operator %||% "unknown"
    rhs <- as.character(it$RightOperand %||% "")
    left <- as.character(it$LeftOperand %||% "")
    # Operands are data, not HTML. In particular, stripping tags from a
    # regex such as <.*> changes the condition. Quote significant whitespace.
    if (op == "MatchesRegex" || !identical(rhs, trimws(rhs)) || grepl("[\r\n\t]", rhs))
      rhs <- encodeString(rhs, quote = '"')
    if (type == "Question") {
      qid <- it$QuestionID %||% sub("^q://([^/]+).*", "\\1", left)
      q <- lookup[[qid]]
      tag <- flowchart_text(q$DataExportTag)
      if (!nzchar(tag) || identical(tag, qid)) {
        tag <- flowchart_text(q$QuestionText)
        # Instruction paragraphs following the question need not be repeated
        # in a branch label. Never truncate a choice or a condition operand.
        if (grepl("?", tag, fixed = TRUE)) tag <- sub("[?].*$", "?", tag)
      }
      if (!nzchar(tag)) tag <- qid
      left <- tag
      loc <- it$ChoiceLocator %||% it$LeftOperand %||% ""
      # Only translate the simple choice form; matrix/other locators must
      # remain explicit so that rows/columns cannot silently disappear.
      if (grepl("^q://[^/]+/SelectableChoice/[^/]+$", loc) &&
          op %in% c("Selected", "NotSelected")) {
        ch <- sub(".*/", "", loc)
        choice <- q$Choices[[ch]]
        if (!is.null(choice)) rhs <- flowchart_text(if (is.list(choice)) choice$Display else choice)
        else rhs <- paste("choice", ch)
      } else if (nzchar(loc)) {
        # A matrix row, text-entry field or choice value is part of the
        # operand, even when a separate comparison value is present.
        left <- paste0(left, " [", loc, "]")
        if (op %in% c("Selected", "NotSelected")) {
          return(paste("Untranslated choice condition:", left, op, rhs))
        }
      }
    } else if (type == "Quota") {
      left <- paste("Quota", it$QuotaName %||% it$QuotaID %||% left)
      if (!is.null(it$SubQuotaID) && nzchar(it$SubQuotaID))
        left <- paste(left, "subquota", it$SubQuotaID)
      if (grepl("/QuotaCount$", it$LeftOperand %||% "")) left <- paste(left, "count")
    } else if (type != "EmbeddedField") {
      return(paste0("Untranslated condition [", type, "]: ", left, " ", op, " ", rhs))
    }
    words <- c(Selected = "is", NotSelected = "is not", EqualTo = "equals",
               NotEqualTo = "does not equal", GreaterThan = "is greater than",
               GreaterThanOrEqual = "is at least", LessThan = "is less than",
               LessThanOrEqual = "is at most", Contains = "contains",
               DoesNotContain = "does not contain", MatchesRegex = "matches pattern",
               Displayed = "is shown", NotDisplayed = "is not shown",
               Empty = "is blank", NonEmpty = "is answered", NotEmpty = "is answered",
               QuotaMet = "is met", QuotaNotMet = "is not met")
    if (!op %in% names(words)) return(paste0("Untranslated operator [", op, "]: ", left, " ", rhs))
    if (op %in% c("Displayed", "NotDisplayed", "Empty", "NonEmpty", "NotEmpty", "QuotaMet", "QuotaNotMet")) rhs <- ""
    trimws(paste(left, words[[op]], rhs))
  }
  # Parenthesised AND terms separated by OR preserve Qualtrics precedence.
  join <- function(text, conjunction) {
    terms <- list(text[1])
    for (k in seq_along(text)[-1]) {
      if (conjunction[k] == "or") terms[[length(terms) + 1L]] <- text[k]
      else terms[[length(terms)]] <- c(terms[[length(terms)]], text[k])
    }
    terms <- vapply(terms, function(t) {
      s <- paste(t, collapse = " and ")
      if (length(t) > 1L) paste0("(", s, ")") else s
    }, "")
    paste(terms, collapse = " or ")
  }
  bl <- node$BranchLogic
  keys <- names(bl)[grepl("^[0-9]+$", names(bl))]
  if (!length(keys)) return("Untranslated branch condition")
  groups <- lapply(bl[keys], function(g) {
    its <- g[names(g)[grepl("^[0-9]+$", names(g))]]
    if (!length(its)) return("Untranslated condition group")
    cj <- vapply(its, function(it) tolower(it$Conjuction %||% it$Conjunction %||% "and"), "")
    if (any(!cj %in% c("and", "or"))) return(paste("Untranslated conjunction:",
      jsonlite::toJSON(g, auto_unbox = TRUE)))
    s <- join(vapply(its, literal, ""), cj)
    if (length(its) > 1L) paste0("(", s, ")") else s
  })
  cj <- vapply(bl[keys], function(g) {
    t <- g$Type %||% "AndIf"
    if (t %in% c("ElseIf", "OrIf", "Or")) "or"
    else if (t %in% c("If", "AndIf")) "and" else "unknown"
  }, "")
  if (any(cj == "unknown")) return(paste("Untranslated group conjunction:",
    jsonlite::toJSON(bl, auto_unbox = TRUE)))
  join(unlist(groups), cj)
}

flow_graph <- function(qsf, routes = NULL, report = NULL,
                       collapse_ends = TRUE, merge_chains = TRUE,
                       include_medians = TRUE) {
  live <- resolve_live_blocks(qsf)
  lookup <- flowchart_lookup(qsf)
  if (is.null(report)) {
    scored <- score_burden(parse_qsf(qsf))
    points <- tapply(scored$gfs_points, scored$block_id, sum, na.rm = TRUE)
  } else points <- stats::setNames(report$blocks$gfs_points, report$blocks$block_id)
  counted <- !is.null(routes)
  all_routes <- if (counted) routes$path_id else integer()
  N <- E <- list()
  node <- function(type, lines, rr, block_id = NA_character_, loop = NA_real_) {
    id <- length(N) + 1L
    N[[id]] <<- list(id = id, type = type, lines = lines, route_ids = rr,
                    block_id = block_id, loop_max = loop)
    id
  }
  pred <- function(id, rr, label = "") list(id = id, rr = rr, label = label)
  link <- function(ps, id, rr) for (p in ps) {
    used <- intersect(p$rr, rr)
    E[[length(E) + 1L]] <<- list(from = p$id, to = id, label = p$label,
                                route_ids = used)
  }
  restrict <- function(ps, rr) lapply(ps, function(p) { p$rr <- intersect(p$rr, rr); p })
  end_note <- function(rr) {
    if (!counted) return("Route counts unavailable")
    note <- sprintf("%d route%s", length(rr), if (length(rr) == 1L) "" else "s")
    if (include_medians && !is.null(report) && length(rr)) {
      med <- report$paths$burden_median[match(rr, report$paths$path_id)]
      if (all(is.finite(med))) note <- paste0(note, ", median of route medians ",
                                              flowchart_points(stats::median(med)))
      else note <- paste0(note, ", median unavailable")
    }
    note
  }
  ends <- list()
  finish <- function(ps, rr, early = TRUE) {
    key <- if (!early) "complete" else if (collapse_ends) "early" else paste0("early", length(ends))
    id <- ends[[key]]
    if (is.null(id)) {
      id <- node(if (early) "end_early" else "end_ok",
                 if (early) "Screen-out" else "End of survey", rr)
      ends[[key]] <<- id
    } else N[[id]]$route_ids <<- union(N[[id]]$route_ids, rr)
    link(ps, id, rr)
  }
  visible <- function(ns) any(vapply(ns, function(n) {
    is.list(n) && ((n$Type %||% "") %in% c("Standard", "Block", "EndSurvey") ||
                    (is.list(n$Flow) && visible(n$Flow)))
  }, logical(1)))
  walk <- function(ns, ps, rr, top = FALSE) {
    for (n in ns) {
      type <- n$Type %||% ""
      if (type %in% c("Standard", "Block")) {
        i <- match(n$ID, live$block_id)
        label <- flowchart_text(live$block_name[i])
        if (is.na(label) || !nzchar(label)) label <- n$ID
        loop <- if (isTRUE(live$in_loop[i])) live$loop_max[i] else NA_real_
        if (!is.na(loop)) label <- paste0(label, " (up to ", loop, " times)")
        id <- node("block", c(label, flowchart_points(unname(points[n$ID]))), rr, n$ID, loop)
        link(ps, id, rr); ps <- list(pred(id, rr))
      } else if (type == "Branch" && visible(n$Flow)) {
        id <- node("branch", describe_branch(n, lookup), rr)
        link(ps, id, rr)
        yes <- if (counted) rr[vapply(match(rr, routes$path_id), function(r) {
          isTRUE(unname(routes$decisions[[r]][n$FlowID %||% "branch"]))
        }, logical(1))] else rr
        no <- setdiff(rr, yes)
        out <- walk(n$Flow, list(pred(id, yes, "yes")), yes)
        ps <- c(out, list(pred(id, no, "no")))
      } else if (type == "EndSurvey") {
        # At the root this is the natural end. Nested ends terminate the
        # containing flow and all subsequent nodes on that branch.
        if (counted && length(rr)) {
          early <- rr[routes$terminates_early[match(rr, routes$path_id)]]
          if (length(early)) finish(restrict(ps, early), early, TRUE)
          complete <- setdiff(rr, early)
          if (length(complete)) finish(restrict(ps, complete), complete, FALSE)
        } else finish(ps, rr, early = !top)
        return(list())
      } else if (type == "BlockRandomizer" && visible(n$Flow)) {
        m <- randomiser_subset(n)
        label <- if (is.na(m)) "Randomiser: selection unknown" else
          sprintf("Randomiser: show %d of %d", min(m, length(n$Flow)), length(n$Flow))
        id <- node("rand", label, rr); link(ps, id, rr)
        # Arms show selected units, not their random temporal order.
        out <- list()
        for (child in n$Flow) {
          cr <- if (counted) rr[vapply(match(rr, routes$path_id), function(r) {
            isTRUE((child$FlowID %||% "") %in% routes$flow_ids[[r]])
          }, logical(1))] else rr
          out <- c(out, walk(list(child), list(pred(id, cr, "selected")), cr))
        }
        # Empty/non-visual arms can also continue.
        continuing <- rr
        missing <- integer()
        if (counted) {
          covered <- unique(unlist(lapply(out, `[[`, "rr")))
          terminated <- unique(unlist(lapply(N[vapply(N, function(z) z$type %in% c("end_ok", "end_early"), logical(1))], `[[`, "route_ids")))
          missing <- setdiff(rr, union(covered, terminated))
          continuing <- union(covered, missing)
        }
        j <- node("join", "Continue after selected elements", continuing)
        link(out, j, continuing)
        if (length(missing)) link(list(pred(id, missing)), j, missing)
        ps <- list(pred(j, continuing))
      } else if (is.list(n$Flow)) {
        ps <- walk(n$Flow, ps, rr, top = top && type %in% c("Group", "Authenticator"))
      }
      if (length(ps)) rr <- unique(unlist(lapply(ps, `[[`, "rr"))) else rr <- integer()
      if (!length(ps)) return(list())
    }
    ps
  }
  s <- node("start", "Start", all_routes)
  ps <- walk(qsf_flow(qsf)$Flow %||% list(), list(pred(s, all_routes)), all_routes, TRUE)
  if (length(ps)) finish(ps, unique(unlist(lapply(ps, `[[`, "rr"))), FALSE)
  for (id in unlist(ends)) N[[id]]$lines <- c(N[[id]]$lines, end_note(N[[id]]$route_ids))
  nodes <- data.frame(id = seq_along(N), type = vapply(N, `[[`, "", "type"))
  nodes$lines <- lapply(N, `[[`, "lines")
  nodes$route_ids <- lapply(N, `[[`, "route_ids")
  nodes$block_id <- vapply(N, `[[`, "", "block_id")
  nodes$loop_max <- vapply(N, `[[`, 0, "loop_max")
  edges <- data.frame(from = vapply(E, `[[`, 1L, "from"), to = vapply(E, `[[`, 1L, "to"),
                      label = vapply(E, `[[`, "", "label"))
  edges$route_ids <- lapply(E, `[[`, "route_ids")
  edges$n_routes <- if (counted) lengths(edges$route_ids) else rep(NA_integer_, nrow(edges))
  if (merge_chains) {
    # Merge only unambiguous, non-loop block chains. Keep all names.
    repeat {
      pair <- which(vapply(seq_len(nrow(edges)), function(k) {
        a <- match(edges$from[k], nodes$id); b <- match(edges$to[k], nodes$id)
        nodes$type[a] == "block" && nodes$type[b] == "block" &&
          is.na(nodes$loop_max[a]) && is.na(nodes$loop_max[b]) &&
          sum(edges$from == nodes$id[a]) == 1L && sum(edges$to == nodes$id[b]) == 1L
      }, logical(1)))
      if (!length(pair)) break
      k <- pair[1]; a <- match(edges$from[k], nodes$id); b <- match(edges$to[k], nodes$id)
      nodes$lines[[a]] <- c(nodes$lines[[a]], nodes$lines[[b]])
      edges$from[edges$from == nodes$id[b]] <- nodes$id[a]
      edges <- edges[-k, , drop = FALSE]; nodes <- nodes[-b, , drop = FALSE]
    }
  }
  map <- stats::setNames(seq_len(nrow(nodes)), nodes$id)
  edges$from <- unname(map[as.character(edges$from)]); edges$to <- unname(map[as.character(edges$to)])
  nodes$id <- seq_len(nrow(nodes))
  list(nodes = nodes, edges = edges, n_routes = if (counted) nrow(routes) else NA_integer_)
}

flowchart_points <- function(x) {
  if (!is.finite(x)) return("GfS+ points unavailable")
  x <- round(x, 1)
  paste(format(x, trim = TRUE), if (x == 1) "GfS+ point" else "GfS+ points")
}
