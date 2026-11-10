#' SmartLoan API
#' @apiTitle SmartLoan Classroom API

#' Application readiness
#' @get /api/health
function() {
  list(status = "ok", model = bundle$model_name, dataset = bundle$data_kind)
}

#' Form options, examples, and evaluation
#' @get /api/project
function() {
  list(model = bundle$model_name, dataset = bundle$data_kind, threshold = bundle$config$threshold,
       rows = sum(split_summary$Records), splits = split_summary, validation = validation_metrics,
       test = test_metrics, examples = examples, features_used = as.list(names(bundle$preprocessing)),
       charts = as.list(sort(list.files(plot_dir, pattern = "[.]png$"))))
}

#' Score one fictional classroom profile
#' @post /api/predict
function(req, res) {
  bad_request <- function(message, status = 400L) {
    res$status <- status
    list(error = message)
  }
  if (!length(req$postBody) || nchar(req$postBody, type = "bytes") > 4096) {
    return(bad_request("Send one applicant profile as a small JSON object."))
  }
  body <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(body) || !length(body) || is.null(names(body)) || anyDuplicated(names(body))) {
    return(bad_request("Send one applicant profile as a JSON object."))
  }
  expected <- names(fields)
  if (length(setdiff(names(body), expected))) {
    return(bad_request("Unexpected fields: provide only the documented applicant parameters."))
  }
  missing <- setdiff(expected, names(body))
  if (length(missing)) return(bad_request(paste("Missing fields:", paste(missing, collapse = ", ")), 422L))
  scalar <- function(x) is.null(x) || ((is.character(x) || is.numeric(x)) && length(x) == 1L)
  if (!all(vapply(body, scalar, logical(1)))) {
    return(bad_request("Each field must be a single number, text value, or null.", 422L))
  }
  raw <- as.data.frame(lapply(body[expected], function(x) if (is.null(x)) NA else x))
  clean <- tryCatch(clean_inputs(raw), error = function(e) e)
  if (inherits(clean, "error")) return(bad_request(conditionMessage(clean), 422L))
  prepared <- apply_preprocessing(clean, bundle$preprocessing)
  score_y <- as.numeric(probability_yes(bundle$model, prepared))
  if (length(score_y) != 1L || !is.finite(score_y)) stop("The model returned an invalid score.")
  # Change only the credit-history flag for a model sensitivity comparison.
  variants <- clean[rep(1L, 2L), , drop = FALSE]
  variants$Credit_History <- c("0", "1")
  variant_scores <- probability_yes(bundle$model, apply_preprocessing(variants, bundle$preprocessing))
  scenarios <- data.frame(credit_history = variants$Credit_History, score_y = round(variant_scores, 6),
    predicted_status = ifelse(variant_scores >= bundle$config$threshold, "Y", "N"))
  list(predicted_status = if (score_y >= bundle$config$threshold) "Y" else "N",
       score_y = round(score_y, 6), threshold = bundle$config$threshold,
       model = bundle$model_name, dataset = bundle$data_kind,
       scenarios = scenarios,
       imputed_fields = as.list(names(prepared)[vapply(names(prepared), function(field) {
         value <- clean[[field]]
         is.na(value) || (!is.null(bundle$preprocessing[[field]]$levels) &&
                          !value %in% bundle$preprocessing[[field]]$levels)
       }, logical(1))]))
}

#' Open the SmartLoan interface
#' @get /
#' @serializer html
function(res) {
  res$status <- 302L
  res$setHeader("Location", "/app/index.html")
  "Open SmartLoan"
}
