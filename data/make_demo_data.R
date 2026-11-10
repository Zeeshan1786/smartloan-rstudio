# Deterministic, fictional records for an offline classroom demonstration.
make_demo_data <- function(path, n = 650L) {
  set.seed(4712)
  applicant <- round(rlnorm(n, log(4800), .51))
  coapplicant <- ifelse(runif(n) < .42, 0, round(rlnorm(n, log(2100), .60)))
  amount <- round(pmax(20, rnorm(n, 118 + applicant / 130, 35)))
  term <- sample(c(120, 180, 240, 300, 360, 480), n, TRUE, c(.03, .12, .03, .05, .74, .03))
  history <- rbinom(n, 1L, .79)
  # A noisy rule for demonstration only, with no demographic inputs.
  log_odds <- -.95 + 2.45 * history + .55 * log((applicant + coapplicant) / 5500) -
    1.1 * (amount * 1000 / term / (applicant + coapplicant) - .13)
  demo <- data.frame(
    Loan_ID = sprintf("DEMO%04d", seq_len(n)),
    Gender = sample(c("Female", "Male"), n, TRUE),
    Married = sample(c("No", "Yes"), n, TRUE),
    Dependents = sample(c("0", "1", "2", "3+"), n, TRUE, c(.55, .20, .15, .10)),
    Education = sample(c("Graduate", "Not Graduate"), n, TRUE, c(.76, .24)),
    Self_Employed = sample(c("No", "Yes"), n, TRUE, c(.85, .15)),
    ApplicantIncome = applicant, CoapplicantIncome = coapplicant, LoanAmount = amount,
    Loan_Amount_Term = term, Credit_History = history,
    Property_Area = sample(c("Rural", "Semiurban", "Urban"), n, TRUE),
    Loan_Status = ifelse(rbinom(n, 1L, plogis(log_odds)) == 1L, "Y", "N")
  )
  for (field in c("Gender", "Dependents", "Self_Employed", "LoanAmount", "Loan_Amount_Term", "Credit_History")) {
    demo[sample.int(n, round(n * .045)), field] <- NA
  }
  write.csv(demo, path, row.names = FALSE, na = "")
  invisible(path)
}
