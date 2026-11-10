# Launch from the SmartLoan project folder: Rscript RunWeb.R
if (!file.exists("R/core.R")) stop("Open SmartLoan.Rproj first.")
source("R/core.R")
install_if_needed(c("plumber", "jsonlite", "ranger", "rpart"))
artifacts <- c("models/best_loan_model.rds", "results/split_summary.csv",
               "results/validation_metrics.csv", "results/model_performance_metrics.csv")
cached <- if (file.exists(artifacts[1])) tryCatch(readRDS(artifacts[1]), error = function(e) NULL)
if (!all(file.exists(artifacts)) || !dir.exists("plots") || !identical(cached$schema_version, 2L)) {
  message("Training once to generate the artifacts required by the app.")
  source("SmartLoan.R", local = new.env())
}
bundle <- readRDS(artifacts[1])
split_summary <- read.csv(artifacts[2])
validation_metrics <- read.csv(artifacts[3])
test_metrics <- read.csv(artifacts[4])
examples <- read.csv("data/example_applicants.csv", colClasses = "character")[names(fields)]
plot_dir <- normalizePath("plots")
router <- plumber::pr("web/api.R", envir = environment())
router <- plumber::pr_set_serializer(router, plumber::serializer_unboxed_json(digits = 8, na = "null"))
router <- plumber::pr_static(router, "/app", normalizePath("web/frontend"))
router <- plumber::pr_static(router, "/charts", plot_dir)
port <- suppressWarnings(as.integer(Sys.getenv("SMARTLOAN_PORT", "3840")))
if (is.na(port) || port < 1L || port > 65535L) stop("Set SMARTLOAN_PORT to a valid port number.")
router$run(host = "127.0.0.1", port = port)
