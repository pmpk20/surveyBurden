test_that("bundled flow graphs have stable nodes, edges and conserved counts", {
  expected <- list(demo_simple_linear = c(5, 4, 1), demo_display_logic = c(9, 8, 2),
                   demo_large_branching = c(17, 19, 9), demo_travel_survey = c(18, 19, 4))
  for (name in names(expected)) {
    q <- read_qsf(system.file("extdata", paste0(name, ".qsf"), package = "surveyBurden"))
    r <- suppressMessages(resolve_flow(q))
    m <- flow_graph(q, r, merge_chains = FALSE)
    expect_equal(c(nrow(m$nodes), nrow(m$edges), m$n_routes), expected[[name]], info = name)
    for (i in m$nodes$id) {
      incoming <- sum(m$edges$n_routes[m$edges$to == i])
      outgoing <- sum(m$edges$n_routes[m$edges$from == i])
      visits <- length(m$nodes$route_ids[[i]])
      if (m$nodes$type[i] != "start") expect_equal(incoming, visits, info = name)
      if (!m$nodes$type[i] %in% c("end_ok", "end_early")) expect_equal(outgoing, visits, info = name)
    }
    ends <- which(m$nodes$type %in% c("end_ok", "end_early"))
    expect_equal(sum(lengths(m$nodes$route_ids[ends])), nrow(r))
    # Every retained route enters and leaves each visited non-terminal box
    # exactly once. Counts alone would miss swapped route identifiers.
    for (route in r$path_id) {
      used <- vapply(m$edges$route_ids, function(z) route %in% z, logical(1))
      for (i in which(vapply(m$nodes$route_ids, function(z) route %in% z, logical(1)))) {
        if (m$nodes$type[i] != "start") expect_equal(sum(used & m$edges$to == i),1L)
        if (!m$nodes$type[i] %in% c("end_ok","end_early")) expect_equal(sum(used & m$edges$from == i),1L)
      }
    }
  }
})

test_that("labels preserve operators, negation and Boolean precedence", {
  one <- function(it) list(BranchLogic = fg_logic(it))
  expect_equal(describe_branch(one(fg_emb("age", "GreaterThan", "18"))), "age is greater than 18")
  words <- c(EqualTo = "equals", NotEqualTo = "does not equal", LessThan = "is less than",
             LessThanOrEqual = "is at most", GreaterThanOrEqual = "is at least",
             Contains = "contains", DoesNotContain = "does not contain", MatchesRegex = "matches pattern")
  for (op in names(words)) expect_equal(describe_branch(one(fg_emb("x", op, "v"))),
    paste("x", words[[op]], if (op == "MatchesRegex") '"v"' else "v"))
  expect_equal(describe_branch(one(fg_emb("code","MatchesRegex","<.*>"))), 'code matches pattern "<.*>"')
  for (op in c("Displayed", "NotDisplayed", "Empty", "NonEmpty")) {
    expect_false(grepl("discard", describe_branch(one(fg_emb("x", op, "discard")))))
  }
  a <- fg_emb("a", "EqualTo", "1")
  b <- fg_emb("b", "EqualTo", "2", "Or")
  c <- fg_emb("c", "NotEqualTo", "3", "And")
  # Qualtrics exports the misspelling Conjuction; accept Conjunction too.
  expect_equal(describe_branch(list(BranchLogic = fg_logic(a,b,c))),
               "(a equals 1 or (b equals 2 and c does not equal 3))")
  b$Conjunction <- b$Conjuction; b$Conjuction <- NULL
  expect_equal(describe_branch(list(BranchLogic = fg_logic(a,b))), "(a equals 1 or b equals 2)")
  groups <- list(`0` = list(`0` = a, Type = "If"),
                 `1` = list(`0` = b, Type = "ElseIf"),
                 `2` = list(`0` = c, Type = "AndIf"), Type = "BooleanExpression")
  expect_equal(describe_branch(list(BranchLogic = groups)),
               "a equals 1 or (b equals 2 and c does not equal 3)")
  q <- fg_mc("Q1", 2); q$DataExportTag <- "employment"
  lit <- lp_sel("Q1", "1"); lit$Operator <- "NotSelected"
  expect_equal(describe_branch(one(lit), list(Q1=q)), "employment is not c 1")
  q$DataExportTag <- "Q1"; q$QuestionText <- "<p>Are you employed?</p>"
  expect_equal(describe_branch(one(lit), list(Q1=q)), "Are you employed? is not c 1")
  value <- list(LogicType="Question",QuestionID="Q1",Operator="GreaterThan",RightOperand="10",
                LeftOperand="q://Q1/ChoiceTextEntryValue/1",ChoiceLocator="q://Q1/ChoiceTextEntryValue/1")
  expect_match(describe_branch(one(value),list(Q1=q)),"ChoiceTextEntryValue/1.*is greater than 10")
  value$Operator <- "NotEmpty"
  expect_match(describe_branch(one(value),list(Q1=q)),"ChoiceTextEntryValue/1.*is answered$")
  value$Operator <- "Selected"; value$ChoiceLocator <- "q://Q1/SelectableChoice/1/SelectableAnswer/2"
  expect_match(describe_branch(one(value),list(Q1=q)),"Untranslated choice condition.*SelectableAnswer/2.*10")
  quota <- list(LogicType = "Quota", QuotaID = "QO_12345678901", QuotaName = "Students", Operator = "QuotaMet")
  expect_equal(describe_branch(one(quota)), "Quota Students is met")
  quota$Operator <- "QuotaNotMet"
  expect_equal(describe_branch(one(quota)), "Quota Students is not met")
  quota$LeftOperand <- "qo://QO_12345678901/QuotaCount"; quota$SubQuotaID <- "1"
  quota$Operator <- "GreaterThanOrEqual"; quota$RightOperand <- "20"
  expect_equal(describe_branch(one(quota)), "Quota Students subquota 1 count is at least 20")
  quota$Operator <- "FutureOperator"
  expect_match(describe_branch(one(quota)), "Untranslated operator.*FutureOperator")
  expect_match(describe_branch(one(list(LogicType = "FutureType", LeftOperand = "raw", Operator = "op", RightOperand = "value"))), "FutureType.*raw op value")
  expect_match(flowchart_points(1), "1 GfS[+] point$")
})

test_that("every bundled branch label agrees with an independent QSF translation", {
  # Separate oracle: retain literal order and connectors directly from the
  # export. No calls to describe_branch or the display-logic parser here.
  for (file in list.files(system.file("extdata", package = "surveyBurden"), "[.]qsf$", full.names = TRUE)) {
    q <- read_qsf(file); lookup <- flowchart_lookup(q)
    flow_walk(qsf_flow(q)$Flow, function(n) {
      if (!identical(n$Type, "Branch")) return()
      text <- describe_branch(n, lookup)
      for (g in n$BranchLogic[names(n$BranchLogic)[grepl("^[0-9]+$", names(n$BranchLogic))]]) {
        if (identical(g$Type, "ElseIf")) expect_match(text, " or ")
        for (lit in g[names(g)[grepl("^[0-9]+$", names(g))]]) {
          if (identical(lit$LogicType, "Question")) {
            question <- lookup[[lit$QuestionID]]
            ch <- sub(".*/", "", lit$ChoiceLocator %||% lit$LeftOperand)
            if (ch %in% names(question$Choices))
              expect_true(grepl(flowchart_text(question$Choices[[ch]]$Display), text, fixed = TRUE))
            if (identical(lit$Operator, "NotSelected")) expect_match(text, "is not")
          } else if (identical(lit$LogicType, "EmbeddedField")) {
            expect_true(grepl(lit$LeftOperand, text, fixed = TRUE))
            expect_true(grepl(lit$RightOperand, text, fixed = TRUE))
          }
        }
      }
    })
  }
})

test_that("complete bundled branch labels match the checked survey logic", {
  expected <- list(
    demo_display_logic = c(FL_b1="Do you consent to participate? is No"),
    demo_large_branching = c(FL_b_consent="Do you consent? is No",
      FL_b_car="Do you own a car? is Yes", FL_b_employed="Employment status? is Full-time",
      FL_b_cycle="How often: Bicycle? is 5+ days/week"),
    demo_travel_survey = c(FL_b_consent="Do you agree to take part in this fictional survey? is No, I do not agree",
      FL_b_area="Which of these best describes where you live right now? is not Inside the study area",
      FL_b_work=paste("Which best describes your current situation? is Employed or",
                     "Which best describes your current situation? is Self-employed")))
  for (name in names(expected)) {
    q <- read_qsf(system.file("extdata",paste0(name,".qsf"),package="surveyBurden"))
    actual <- character()
    flow_walk(qsf_flow(q)$Flow,function(n) if (identical(n$Type,"Branch"))
      actual[n$FlowID] <<- describe_branch(n,flowchart_lookup(q)))
    expect_equal(actual,expected[[name]])
  }
})

test_that("randomiser selections and nested groups retain counts", {
  # Build independently of tests in other files.
  q <- lp_qsf(list(list(id="A", qs=list(fg_mc("Q1",2))),
                   list(id="B", qs=list(fg_mc("Q2",2))),
                   list(id="C", qs=list(fg_mc("Q3",2)))))
  f <- which(vapply(q$SurveyElements, function(e) e$Element == "FL", logical(1)))
  blocks <- q$SurveyElements[[f]]$Payload$Flow
  branch <- list(Type="Branch", FlowID="BR", BranchLogic=fg_logic(fg_emb("x","EqualTo","1")), Flow=list(blocks[[2]]))
  group <- list(Type="Group", FlowID="GR", Flow=list(branch, blocks[[3]]))
  for (count in c(1,2)) {
    q$SurveyElements[[f]]$Payload$Flow <- list(list(Type="BlockRandomizer", FlowID="RAND", SubSet=count,
                                                 Flow=list(blocks[[1]], group)))
    r <- suppressMessages(resolve_flow(q))
    m <- flow_graph(q,r,merge_chains=FALSE)
    rand <- which(m$nodes$type == "rand")
    selected <- m$edges[m$edges$from == rand, ]
    expect_equal(sort(selected$n_routes), if (count == 1) c(1L,2L) else c(2L,2L))
    expect_equal(length(m$nodes$route_ids[[which(m$nodes$type == "end_ok")]]), nrow(r))
    expect_equal(m$edges$n_routes[m$nodes$type[m$edges$from] == "branch" & m$edges$label == "yes"], 1L)
  }
})

test_that("adjacent branch arms remain separate randomiser selection units", {
  q <- lp_qsf(list(list(id="A",qs=list(fg_mc("Q1",2))),list(id="B",qs=list(fg_mc("Q2",2)))))
  f <- which(vapply(q$SurveyElements,function(e) e$Element == "FL",logical(1)))
  blocks <- q$SurveyElements[[f]]$Payload$Flow
  arms <- lapply(1:2,function(i) list(Type="Branch",FlowID=paste0("BR",i),
    BranchLogic=fg_logic(fg_emb("flag","EqualTo","1")),Flow=list(blocks[[i]])))
  q$SurveyElements[[f]]$Payload$Flow <- list(list(Type="BlockRandomizer",FlowID="RAND",SubSet=1,Flow=arms))
  r <- suppressMessages(resolve_flow(q,field_domains=list(flag="1")))
  expect_equal(nrow(r),2L)
  expect_setequal(vapply(r$block_ids,paste,"",collapse=">"),c("A","B"))
  m <- flow_graph(q,r,merge_chains=FALSE)
  rand <- which(m$nodes$type == "rand")
  expect_equal(m$edges$n_routes[m$edges$from == rand],c(1L,1L))
  expect_true(all(vapply(r$flow_ids,function(ids) sum(c("BR1","BR2") %in% ids) == 1L,logical(1))))
})

test_that("plots, reports, loop arrows and route-cap fallback work", {
  skip_if_not_installed("ggplot2")
  withr::local_pdf(tempfile(fileext = ".pdf"))
  f <- system.file("extdata", "demo_travel_survey.qsf", package="surveyBurden")
  report <- suppressMessages(burden_report(f, profile=FALSE, certainty=FALSE))
  expect_true("block_ids" %in% names(attr(report,"route_flowchart")$routes))
  for (direction in c("LR", "TB")) {
    p <- plot_route_flowchart(report,direction=direction,highlight_route=1,merge_chains=FALSE,
                             title=paste(rep("A long title",20),collapse=" "))
    expect_s3_class(p,"ggplot")
    expect_no_error(ggplot2::ggplot_build(p))
    lay <- attr(p,"flowchart_layout")
    expect_true(all(is.finite(unlist(lapply(lay$polys,function(x) c(x$x,x$y))))))
    # A bypass must not pass through an unrelated rectangular block.
    for (k in seq_along(lay$polys)) {
      poly <- lay$polys[[k]]
      for (j in which(lay$nodes$type == "block" &
                      !lay$nodes$id %in% c(lay$edges$from[k],lay$edges$to[k]))) {
        box <- lay$nodes[j,]
        inside <- FALSE
        for (s in seq_len(nrow(poly)-1L)) {
          xx <- range(poly$x[c(s,s+1L)]); yy <- range(poly$y[c(s,s+1L)])
          inside <- inside || (xx[2] > box$x-box$w/2+1e-8 && xx[1] < box$x+box$w/2-1e-8 &&
                                yy[2] > box$y-box$h/2+1e-8 && yy[1] < box$y+box$h/2-1e-8)
        }
        expect_false(inside)
      }
    }
  }
  linear <- system.file("extdata","demo_simple_linear.qsf",package="surveyBurden")
  p <- plot_route_flowchart(linear)
  expect_equal(nrow(attr(p,"model")$nodes),3L)
  expect_warning(p <- suppressMessages(plot_route_flowchart(f,max_routes=1)), "Route cap exceeded")
  expect_true(all(is.na(attr(p,"model")$edges$n_routes)))
  expect_no_error(ggplot2::ggplot_build(p))
  q <- lp_qsf(list(list(id="A",qs=list(fg_mc("Q1",2)),loop=3)))
  p <- suppressMessages(plot_route_flowchart(q))
  expect_match(paste(unlist(attr(p,"model")$nodes$lines),collapse=" "),"up to 3 times")
  expect_true(any(vapply(p$layers,function(l) identical(l$aes_params$linetype,"dashed"),logical(1))))
  expect_error(plot_route_flowchart(f,wrap=NA),"wrap")
  expect_error(plot_route_flowchart(f,highlight_route=999),"highlight_route")
  old <- report; attr(old,"route_flowchart") <- NULL
  expect_error(plot_route_flowchart(old),"rebuild")
})
