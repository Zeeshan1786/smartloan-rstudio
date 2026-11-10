predict_applications <- function(path, bundle) {
  raw <- read.csv(path, colClasses = "character", check.names = FALSE)
  if (!nrow(raw) || anyDuplicated(names(raw))) stop("Provide applicant rows and unique column names.")
  p <- probability_yes(bundle$model, apply_preprocessing(clean_inputs(raw), bundle$preprocessing))
  data.frame(
    Loan_ID = if ("Loan_ID" %in% names(raw)) raw$Loan_ID else seq_len(nrow(raw)),
    Predicted_Loan_Status = ifelse(p >= bundle$config$threshold, "Y", "N"),
    Model_Score_Y = round(p, 6), Model = bundle$model_name,
    Training_Data = bundle$data_kind, check.names = FALSE
  )
}
