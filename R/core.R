fields <- list(
  Gender = c("Female", "Male"),
  Married = c("No", "Yes"),
  Dependents = c("0", "1", "2", "3+"),
  Education = c("Graduate", "Not Graduate"),
  Self_Employed = c("No", "Yes"),
  ApplicantIncome = c(0, Inf),
  CoapplicantIncome = c(0, Inf),
  LoanAmount = c(0, Inf),
  Loan_Amount_Term = c(0, Inf),
  Credit_History = c("0", "1"),
  Property_Area = c("Rural", "Semiurban", "Urban")
)

clean_inputs <- function(raw) {
  absent <- setdiff(names(fields), names(raw))
  if (length(absent)) stop("Missing input columns: ", paste(absent, collapse = ", "))
  result <- raw[names(fields)]
  for (key in names(fields)) {
    rule <- fields[[key]]
    x <- trimws(as.character(result[[key]]))
    x[!is.na(x) & toupper(x) %in% c("", "NA", "N/A", "NULL")] <- NA
    if (is.numeric(rule)) {
      value <- suppressWarnings(as.numeric(x))
      valid <- is.finite(value) & value >= rule[1] & value <= rule[2]
      if (key %in% c("LoanAmount", "Loan_Amount_Term")) valid <- valid & value > 0
      if (key == "Loan_Amount_Term") valid <- valid & value == floor(value)
    } else {
      if (key == "Dependents") x[!is.na(x) & x == "3"] <- "3+"
      value <- rule[match(tolower(x), tolower(rule))]
      valid <- !is.na(value)
    }
    bad <- which(!is.na(x) & (is.na(valid) | !valid))
    if (length(bad)) stop("Invalid ", key, " at input row(s): ", paste(head(bad, 8), collapse = ", "))
    result[[key]] <- value
  }
  result
}

load_training <- function(path) {
  raw <- read.csv(path, colClasses = "character", check.names = FALSE)
  if (anyDuplicated(names(raw))) stop("The CSV has duplicate column names.")
  if (!"Loan_Status" %in% names(raw)) stop("The training CSV must contain Loan_Status.")
  outcome <- toupper(trimws(raw$Loan_Status))
  outcome <- unname(c("N" = "N", "Y" = "Y", "0" = "N", "1" = "Y")[outcome])
  if (anyNA(outcome)) stop("Loan_Status must contain only Y/N or 1/0.")
  x <- clean_inputs(raw)
  label <- factor(outcome, levels = c("N", "Y"))
  # Remove duplicate feature/label records. Keep remaining identical profiles
  # together during splitting even if their labels disagree.
  unique_rows <- !duplicated(cbind(x, Loan_Status = label))
  list(data = cbind(x, Loan_Status = label)[unique_rows, , drop = FALSE],
       dropped = sum(!unique_rows), missing = colSums(is.na(x[unique_rows, ])))
}

split_data <- function(data, cfg) {
  # Assign profiles rather than rows. Mixed-label profiles form a separate stratum.
  keys <- do.call(paste, c(data[names(fields)], sep = "|"))
  groups <- split(seq_len(nrow(data)), keys)
  strata <- vapply(groups, function(idx) paste(sort(unique(data$Loan_Status[idx])), collapse = ""), "")
  set.seed(cfg$seed)
  allocations <- lapply(split(seq_along(groups), strata), function(ids) {
    n <- length(ids)
    ids <- ids[sample.int(n)]
    if (n < 3L) return(list(train = ids, validation = integer(), test = integer()))
    n_test <- max(1L, floor(n * cfg$test_fraction))
    n_val <- max(1L, floor(n * cfg$validation_fraction))
    list(test = head(ids, n_test), validation = ids[n_test + seq_len(n_val)],
         train = tail(ids, n - n_test - n_val))
  })
  out <- setNames(lapply(c("train", "validation", "test"), function(part) {
    picked <- unlist(lapply(allocations, function(x) x[[part]]), use.names = FALSE)
    sort(unlist(groups[picked], use.names = FALSE))
  }), c("train", "validation", "test"))
  for (idx in out) {
    if (length(unique(data$Loan_Status[idx])) != 2L) {
      stop("Each split needs both approval classes. Supply more distinct labelled profiles.")
    }
  }
  out
}

fit_preprocessing <- function(train) {
  prep <- lapply(names(fields), function(key) {
    x <- train[[key]]
    x <- x[!is.na(x)]
    if (length(unique(x)) < 2L) return(NULL)
    if (is.numeric(fields[[key]])) list(fill = median(x)) else {
      counts <- sort(table(x), decreasing = TRUE)
      list(fill = names(counts)[1], levels = sort(unique(x)))
    }
  })
  names(prep) <- names(fields)
  prep <- Filter(Negate(is.null), prep)
  if (!length(prep)) stop("No variable predictors were available in the training split.")
  prep
}

apply_preprocessing <- function(x, prep) {
  x <- x[names(prep)]
  for (key in names(prep)) {
    spec <- prep[[key]]
    replace <- is.na(x[[key]])
    if (!is.null(spec$levels)) replace <- replace | !x[[key]] %in% spec$levels
    x[[key]][replace] <- spec$fill
    if (!is.null(spec$levels)) x[[key]] <- factor(x[[key]], levels = spec$levels)
  }
  x
}

fit_models <- function(train, cfg) {
  set.seed(cfg$seed)
  models <- list(
    Logistic = glm(Loan_Status ~ ., data = train, family = binomial()),
    Tree = rpart::rpart(Loan_Status ~ ., data = train, method = "class",
      control = rpart::rpart.control(cp = cfg$tree_cp, minsplit = cfg$tree_minsplit, xval = 0L)),
    Forest = ranger::ranger(Loan_Status ~ ., data = train, probability = TRUE,
      num.trees = cfg$forest_trees, min.node.size = cfg$forest_min_node,
      mtry = if (is.null(cfg$forest_mtry)) NULL else min(cfg$forest_mtry, ncol(train) - 1L),
      importance = "permutation", seed = cfg$seed, num.threads = 2L)
  )
  models
}

probability_yes <- function(model, x) {
  if (inherits(model, "ranger")) {
    predict(model, data = x, num.threads = 2L)$predictions[, "Y"]
  } else if (inherits(model, "rpart")) {
    predict(model, newdata = x, type = "prob")[, "Y"]
  } else {
    as.numeric(predict(model, newdata = x, type = "response"))
  }
}

score <- function(actual, p, threshold) {
  if (length(actual) != length(p) || any(!is.finite(p))) stop("Invalid model probabilities.")
  predicted <- factor(ifelse(p >= threshold, "Y", "N"), levels = c("N", "Y"))
  cm <- table(Actual = actual, Predicted = predicted)
  tn <- unname(cm["N", "N"]); fp <- unname(cm["N", "Y"])
  fn <- unname(cm["Y", "N"]); tp <- unname(cm["Y", "Y"])
  ratio <- function(a, b) if (b == 0) NA_real_ else a / b
  # Rank-based AUC with average ranks for tied scores.
  positives <- sum(actual == "Y")
  negatives <- sum(actual == "N")
  auc <- (sum(rank(p)[actual == "Y"]) - positives * (positives + 1) / 2) / (positives * negatives)
  list(metrics = c(Accuracy = (tp + tn) / sum(cm), Precision = ratio(tp, tp + fp),
                   Recall = ratio(tp, tp + fn), Specificity = ratio(tn, tn + fp),
                   F1 = ratio(2 * tp, 2 * tp + fp + fn), ROC_AUC = auc),
       confusion = cm, rows = data.frame(Actual = actual, Predicted = predicted, P_Y = p))
}

install_if_needed <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
  if (any(!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE))) {
    stop("Required packages are missing: ", paste(pkgs, collapse = ", "))
  }
}
