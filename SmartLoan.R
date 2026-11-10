# Open SmartLoan.Rproj in RStudio, then Source this file.
if (!file.exists("R/core.R")) stop("Open SmartLoan.Rproj or set the working directory to the project folder.")
source("R/core.R")
source("R/plots.R")
source("R/predict.R")
source("data/make_demo_data.R")

# Experiment settings. Model choice uses validation F1; the test set is held back.
cfg <- list(seed = 123L, validation_fraction = .14, test_fraction = .30,
            threshold = .50, tree_cp = .01, tree_minsplit = 10L,
            forest_trees = 300L, forest_min_node = 10L, forest_mtry = NULL)
if (!is.finite(cfg$threshold) || cfg$threshold <= 0 || cfg$threshold >= 1 ||
    cfg$validation_fraction <= 0 || cfg$test_fraction <= 0 ||
    cfg$validation_fraction + cfg$test_fraction >= 1) stop("Invalid split fractions or threshold.")

install_if_needed(c("ggplot2", "rpart", "ranger"))
for (d in c("plots", "results", "models")) dir.create(d, showWarnings = FALSE)
external_data <- file.exists("data/train.csv")
data_path <- if (external_data) "data/train.csv" else "data/demo_train.csv"
if (!external_data && !file.exists(data_path)) make_demo_data(data_path)
data_kind <- if (external_data) "User supplied labelled CSV" else "Synthetic classroom demo"
cat("\nData source:", data_kind, "(", data_path, ")\n")

loaded <- load_training(data_path)
data <- loaded$data
indices <- split_data(data, cfg)
split_sizes <- do.call(rbind, lapply(names(indices), function(split) {
  labels <- data$Loan_Status[indices[[split]]]
  data.frame(Split = split, Records = length(labels), N = sum(labels == "N"), Y = sum(labels == "Y"))
}))
print(split_sizes, row.names = FALSE)
write.csv(split_sizes, "results/split_summary.csv", row.names = FALSE)
write.csv(data.frame(Field = names(loaded$missing), Missing = unname(loaded$missing)),
          "results/missing_values.csv", row.names = FALSE)

# Fit preprocessing and all model weights on training records only.
prep <- fit_preprocessing(data[indices$train, ])
prepared <- lapply(indices, function(idx) cbind(
  apply_preprocessing(data[idx, ], prep), Loan_Status = data$Loan_Status[idx]
))
models <- fit_models(prepared$train, cfg)
model_titles <- c(Logistic = "Logistic Regression", Tree = "Decision Tree", Forest = "Random Forest")
evaluate_set <- function(set) lapply(models, function(model) {
  score(set$Loan_Status, probability_yes(model, set[names(prep)]), cfg$threshold)
})
metrics_table <- function(scores) {
  data.frame(Model = unname(model_titles[names(scores)]),
             do.call(rbind, lapply(scores, function(s) s$metrics)), row.names = NULL)
}
validation <- metrics_table(evaluate_set(prepared$validation))
# In a tie, prefer higher AUC, then the first model in the comparison.
winner <- order(-validation$F1, -validation$ROC_AUC)[1L]
selected <- names(models)[winner]
write.csv(validation, "results/validation_metrics.csv", row.names = FALSE)

# The held-out test scores are reported only after selecting a model.
test_scores <- evaluate_set(prepared$test)
test <- metrics_table(test_scores)
write.csv(test, "results/model_performance_metrics.csv", row.names = FALSE)
for (key in names(test_scores)) {
  write.csv(as.data.frame(test_scores[[key]]$confusion),
    file.path("results", paste0("confusion_matrix_", tolower(key), ".csv")), row.names = FALSE)
  write.csv(test_scores[[key]]$rows,
    file.path("results", paste0("test_predictions_", tolower(key), ".csv")), row.names = FALSE)
}
bundle <- list(model = models[[selected]], model_name = unname(model_titles[selected]),
               preprocessing = prep, config = cfg, data_kind = data_kind)
saveRDS(bundle, "models/best_loan_model.rds")
examples <- predict_applications("data/example_applicants.csv", bundle)
write.csv(examples, "results/applicant_predictions.csv", row.names = FALSE)
write_plots(data, prep, models, test_scores, test, "plots")
writeLines(capture.output(sessionInfo()), "results/session_info.txt")

# Build the report from the actual run. No scores are hardcoded.
format_table <- function(tbl) {
  txt <- function(x) if (is.numeric(x)) ifelse(is.na(x), "Undefined", sprintf("%.4f", x)) else x
  rows <- do.call(cbind, lapply(tbl, txt))
  c(paste0("| ", paste(names(tbl), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(tbl)), collapse = " | "), " |"),
    apply(rows, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |")))
}
majority_y <- mean(prepared$train$Loan_Status == "Y") >= .5
baseline <- score(prepared$test$Loan_Status, rep(as.numeric(majority_y), nrow(prepared$test)), cfg$threshold)
plot_files <- sort(list.files("plots", pattern = "[.]png$"))
writeLines(c(
  "# SmartLoan Project Report", "",
  "## Objective", "",
  "Compare three classifiers in R on the task of predicting a recorded loan approval label. This is an academic demonstration and does not measure creditworthiness, default risk, or suitability for real decisions.", "",
  "## Dataset", "",
  paste("Run source:", data_kind, paste0("(", data_path, ").")),
  if (!external_data) "All training records and labels in this run are fictional. The labels follow a noisy simulated rule; the scores are not evidence of performance on real loan applications." else
    "The results use the supplied labelled CSV. Confirm and cite its provenance before submission.",
  sprintf("Usable records: %d. Duplicate feature-and-label records removed: %d.", nrow(data), loaded$dropped),
  paste("Fields used by the fitted models:", paste(names(prep), collapse = ", "), "."),
  paste("Fields omitted because the training split had no variation:",
        if (length(setdiff(names(fields), names(prep)))) paste(setdiff(names(fields), names(prep)), collapse = ", ") else "none."),
  "See [README](README.md) for every input definition and the dataset sources.", "",
  "## Methodology", "",
  "Identical input profiles stay together. Groups are stratified by their recorded label pattern. Medians and modes are fitted on training records only; the validation and test data use those same rules.", "",
  format_table(split_sizes), "",
  sprintf("Seed: %d. Prediction threshold for Y: %.2f. Validation F1 selects the model; AUC breaks ties.", cfg$seed, cfg$threshold),
  sprintf("Decision tree: cp = %.3f and minsplit = %d. Random forest: %d trees, minimum node size %d, mtry = %s.",
          cfg$tree_cp, cfg$tree_minsplit, cfg$forest_trees, cfg$forest_min_node,
          if (is.null(cfg$forest_mtry)) "ranger default" else as.character(cfg$forest_mtry)), "",
  "## Results", "",
  paste("Selected on validation:", bundle$model_name), "",
  "Validation scores:", "", format_table(validation), "",
  "Held-out test scores:", "", format_table(test), "",
  sprintf("The training majority-class baseline predicts %s for every test record and achieves test accuracy %.4f and F1 %.4f.",
    if (majority_y) "Y" else "N", baseline$metrics["Accuracy"], baseline$metrics["F1"]),
  "Accuracy is the overall correct fraction. Precision is the fraction of predicted approvals that were recorded as approved. Recall is the fraction of recorded approvals found. Specificity is the fraction of recorded rejections found. F1 balances precision and recall. ROC AUC measures ranking across thresholds. Undefined metrics indicate a zero denominator.", "",
  "## Interpretation and limitations", "",
  sprintf("The selected model had validation F1 %.4f and held-out test F1 %.4f. Its test ROC AUC was %.4f.",
    validation$F1[winner], test$F1[winner], test$ROC_AUC[winner]),
  "Model scores are not calibrated approval probabilities. Input fields such as gender and marital status are included to demonstrate the assignment schema; these results do not establish fairness or justify using those fields in lending. A single split cannot establish performance across lenders, populations, or time.", "",
  "## Figures", "",
  paste0("- [", sub("[.]png$", "", plot_files), "](plots/", plot_files, ")"), "",
  "## Reproduce", "",
  "Open SmartLoan.Rproj in RStudio, source SmartLoan.R, and inspect results/, plots/, and models/. Then edit data/example_applicants.csv and source PredictLoan.R to score another profile."
), "PROJECT_REPORT.md")
cat("\nSelected using validation F1:", bundle$model_name, "\n\n")
cat("Held-out test performance:\n")
print(test, row.names = FALSE, digits = 4)
cat("\nExample predictions:\n")
print(examples, row.names = FALSE)
cat("\nOutputs: PROJECT_REPORT.md, results/, plots/, and models/.\n")
