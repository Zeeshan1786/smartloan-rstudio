write_plots <- function(data, prep, models, test_scores, metrics, path) {
  save <- function(plot, file, width = 7, height = 4.5) {
    ggplot2::ggsave(file.path(path, file), plot + ggplot2::theme_minimal(base_size = 12),
                   width = width, height = height, dpi = 160, bg = "white")
  }
  gg <- ggplot2::ggplot
  aes <- ggplot2::aes
  save(gg(data, aes(Loan_Status, fill = Loan_Status)) + ggplot2::geom_bar() +
    ggplot2::labs(title = "Recorded loan outcomes", x = "Recorded class", y = "Applications"),
    "01_loan_status.png")
  for (spec in list(c("ApplicantIncome", "02_income.png", "Applicant income"),
                    c("LoanAmount", "03_loan_amount.png", "Loan amount (thousands)"))) {
    save(gg(data[!is.na(data[[spec[1]]]), ], aes(x = .data[[spec[1]]])) +
      ggplot2::geom_histogram(bins = 25, fill = "#246884", colour = "white") +
      ggplot2::labs(title = spec[3], x = spec[3], y = "Applications"), spec[2])
  }
  for (spec in list(c("Education", "04_education.png", "Outcome by education"),
                    c("Credit_History", "05_credit_history.png", "Outcome by credit history"))) {
    save(gg(data, aes(x = .data[[spec[1]]], fill = Loan_Status)) +
      ggplot2::geom_bar(position = "dodge") +
      ggplot2::labs(title = spec[3], x = spec[1], y = "Applications"), spec[2])
  }
  nums <- names(fields)[vapply(fields, is.numeric, logical(1))]
  numeric_data <- data[nums]
  variable <- vapply(numeric_data, function(x) length(unique(na.omit(x))) > 1L, logical(1))
  if (sum(variable) >= 2L) {
    correlations <- suppressWarnings(cor(numeric_data[variable], use = "pairwise.complete.obs"))
    corr <- as.data.frame(as.table(correlations))
    save(gg(corr, aes(Var1, Var2, fill = Freq)) + ggplot2::geom_tile() +
      ggplot2::geom_text(aes(label = sprintf("%.2f", Freq))) +
      ggplot2::scale_fill_gradient2(low = "#b7563c", high = "#246884", limits = c(-1, 1)) +
      ggplot2::labs(title = "Numeric feature correlations", x = NULL, y = NULL, fill = "Pearson r") +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 25, hjust = 1)),
      "06_correlation.png", 8, 5)
  }
  roc <- list()
  for (key in names(test_scores)) {
    evaluation <- test_scores[[key]]
    cells <- as.data.frame(evaluation$confusion)
    save(gg(cells, aes(Predicted, Actual, fill = Freq)) + ggplot2::geom_tile(colour = "white") +
      ggplot2::geom_text(aes(label = Freq), size = 6) +
      ggplot2::labs(title = paste("Test confusion matrix:", key), fill = "Count"),
      paste0("07_confusion_", tolower(key), ".png"))
    pairs <- evaluation$rows[order(-evaluation$rows$P_Y), ]
    last <- c(which(diff(pairs$P_Y) != 0), nrow(pairs))
    roc[[key]] <- data.frame(
      FPR = c(0, cumsum(pairs$Actual == "N")[last] / sum(pairs$Actual == "N")),
      TPR = c(0, cumsum(pairs$Actual == "Y")[last] / sum(pairs$Actual == "Y")), Model = key)
  }
  save(gg(do.call(rbind, roc), aes(FPR, TPR, colour = Model)) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    ggplot2::coord_equal() + ggplot2::labs(title = "Held-out test ROC curves",
      x = "False positive rate", y = "True positive rate"), "08_test_roc.png", 7, 5)
  long <- reshape(metrics, varying = names(metrics)[-1], v.names = "Score",
                  timevar = "Metric", times = names(metrics)[-1], direction = "long")
  save(gg(long, aes(Metric, Score, fill = Model)) + ggplot2::geom_col(position = "dodge", na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) + ggplot2::labs(title = "Held-out test metrics"),
    "09_model_comparison.png", 8.5, 4.5)
  importance <- models$Forest$variable.importance
  imp <- data.frame(Feature = names(importance), Importance = as.numeric(importance))
  save(gg(imp, aes(reorder(Feature, Importance), Importance)) +
    ggplot2::geom_col(fill = "#246884") + ggplot2::coord_flip() +
    ggplot2::labs(title = "Random forest permutation importance", x = NULL),
    "10_forest_importance.png")
  grDevices::png(file.path(path, "11_decision_tree.png"), width = 1200, height = 760, res = 120)
  tryCatch({
    if (nrow(models$Tree$frame) > 1L) {
      plot(models$Tree, uniform = TRUE, margin = .12, main = "Decision tree")
      text(models$Tree, use.n = TRUE, cex = .78)
    } else {
      plot.new()
      title("Decision tree")
      text(.5, .5, paste("Root only; predicted class:", levels(data$Loan_Status)[models$Tree$frame$yval]))
    }
  }, finally = grDevices::dev.off())
}
