# Run after SmartLoan.R. Edit the input CSV or change this path.
applicant_file <- "data/example_applicants.csv"
source("R/core.R")
source("R/predict.R")
if (!file.exists("models/best_loan_model.rds")) stop("Run SmartLoan.R first.")
bundle <- readRDS("models/best_loan_model.rds")
install_if_needed(c("ranger", "rpart"))
predictions <- predict_applications(applicant_file, bundle)
print(predictions, row.names = FALSE)
write.csv(predictions, "results/applicant_predictions.csv", row.names = FALSE)
message("Academic model output only. Do not use it for real lending decisions.")
