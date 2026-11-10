# SmartLoan Project Report

## Objective

Compare three classifiers in R on the task of predicting a recorded loan approval label. This is an academic demonstration and does not measure creditworthiness, default risk, or suitability for real decisions.

## Dataset

Run source: Synthetic classroom demo (data/demo_train.csv).
All training records and labels in this run are fictional. The labels follow a noisy simulated rule; the scores are not evidence of performance on real loan applications.
Usable records: 650. Duplicate feature-and-label records removed: 0.
Fields used by the fitted models: Gender, Married, Dependents, Education, Self_Employed, ApplicantIncome, CoapplicantIncome, LoanAmount, Loan_Amount_Term, Credit_History, Property_Area .
Fields omitted because the training split had no variation: none.
See [README](README.md) for every input definition and the dataset sources.

## Methodology

Identical input profiles stay together. Groups are stratified by their recorded label pattern. Medians and modes are fitted on training records only; the validation and test data use those same rules.

| Split | Records | N | Y |
| --- | --- | --- | --- |
| train | 366.0000 | 117.0000 | 249.0000 |
| validation | 90.0000 | 29.0000 | 61.0000 |
| test | 194.0000 | 62.0000 | 132.0000 |

Seed: 123. Selected model threshold for Y: 0.66. Each model's cutoff maximizes validation balanced accuracy; ties favor a cutoff nearest 0.50. The model with the highest validation balanced accuracy is selected, with AUC as the tie-breaker.
Balanced accuracy is the mean of recall for approvals and specificity for rejections. The test split is the same fixed benchmark as the earlier demo; it was not used to compute these cutoffs.
Decision tree: cp = 0.010 and minsplit = 10. Random forest: 300 trees, minimum node size 10, mtry = ranger default.

## Results

Selected on validation: Logistic Regression

Validation scores:

| Model | Threshold | Accuracy | Precision | Recall | Specificity | Balanced_Accuracy | F1 | ROC_AUC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Logistic Regression | 0.6600 | 0.7667 | 0.8030 | 0.8689 | 0.5517 | 0.7103 | 0.8346 | 0.6574 |
| Decision Tree | 0.2700 | 0.7111 | 0.7536 | 0.8525 | 0.4138 | 0.6331 | 0.8000 | 0.5243 |
| Random Forest | 0.5800 | 0.7778 | 0.7971 | 0.9016 | 0.5172 | 0.7094 | 0.8462 | 0.6642 |

Held-out test scores:

| Model | Threshold | Accuracy | Precision | Recall | Specificity | Balanced_Accuracy | F1 | ROC_AUC |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Logistic Regression | 0.6600 | 0.7216 | 0.7746 | 0.8333 | 0.4839 | 0.6586 | 0.8029 | 0.6883 |
| Decision Tree | 0.2700 | 0.7268 | 0.7616 | 0.8712 | 0.4194 | 0.6453 | 0.8127 | 0.7128 |
| Random Forest | 0.5800 | 0.7577 | 0.7707 | 0.9167 | 0.4194 | 0.6680 | 0.8374 | 0.6953 |

The training majority-class baseline predicts Y for every test record and achieves test accuracy 0.6804 and F1 0.8098.
Accuracy is the overall correct fraction. Precision is the fraction of predicted approvals that were recorded as approved. Recall is the fraction of recorded approvals found. Specificity is the fraction of recorded rejections found. F1 balances precision and recall. ROC AUC measures ranking across thresholds. Undefined metrics indicate a zero denominator.

## Interpretation and limitations

The selected model had validation balanced accuracy 0.7103 and test balanced accuracy 0.6586. It predicted Y for 142 and N for 52 test records.
Model scores are not calibrated approval probabilities. Input fields such as gender and marital status are included to demonstrate the assignment schema; these results do not establish fairness or justify using those fields in lending. A single split cannot establish performance across lenders, populations, or time.

## Figures

- [01_loan_status](plots/01_loan_status.png)
- [02_income](plots/02_income.png)
- [03_loan_amount](plots/03_loan_amount.png)
- [04_education](plots/04_education.png)
- [05_credit_history](plots/05_credit_history.png)
- [06_correlation](plots/06_correlation.png)
- [07_confusion_forest](plots/07_confusion_forest.png)
- [07_confusion_logistic](plots/07_confusion_logistic.png)
- [07_confusion_tree](plots/07_confusion_tree.png)
- [08_test_roc](plots/08_test_roc.png)
- [09_model_comparison](plots/09_model_comparison.png)
- [10_forest_importance](plots/10_forest_importance.png)
- [11_decision_tree](plots/11_decision_tree.png)

## Reproduce

Open SmartLoan.Rproj in RStudio, source SmartLoan.R, and inspect results/, plots/, and models/. Then edit data/example_applicants.csv and source PredictLoan.R to score another profile.
