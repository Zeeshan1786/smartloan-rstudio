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

Seed: 123. Prediction threshold for Y: 0.50. Validation F1 selects the model; AUC breaks ties.
Decision tree: cp = 0.010 and minsplit = 10. Random forest: 300 trees, minimum node size 10, mtry = ranger default.

## Results

Selected on validation: Random Forest

Validation scores:

| Model | Accuracy | Precision | Recall | Specificity | F1 | ROC_AUC |
| --- | --- | --- | --- | --- | --- | --- |
| Logistic Regression | 0.7556 | 0.7532 | 0.9508 | 0.3448 | 0.8406 | 0.6574 |
| Decision Tree | 0.6778 | 0.7424 | 0.8033 | 0.4138 | 0.7717 | 0.5243 |
| Random Forest | 0.7556 | 0.7532 | 0.9508 | 0.3448 | 0.8406 | 0.6642 |

Held-out test scores:

| Model | Accuracy | Precision | Recall | Specificity | F1 | ROC_AUC |
| --- | --- | --- | --- | --- | --- | --- |
| Logistic Regression | 0.7577 | 0.7576 | 0.9470 | 0.3548 | 0.8418 | 0.6883 |
| Decision Tree | 0.7216 | 0.7826 | 0.8182 | 0.5161 | 0.8000 | 0.7128 |
| Random Forest | 0.7423 | 0.7500 | 0.9318 | 0.3387 | 0.8311 | 0.6953 |

The training majority-class baseline predicts Y for every test record and achieves test accuracy 0.6804 and F1 0.8098.
Accuracy is the overall correct fraction. Precision is the fraction of predicted approvals that were recorded as approved. Recall is the fraction of recorded approvals found. Specificity is the fraction of recorded rejections found. F1 balances precision and recall. ROC AUC measures ranking across thresholds. Undefined metrics indicate a zero denominator.

## Interpretation and limitations

The selected model had validation F1 0.8406 and held-out test F1 0.8311. Its test ROC AUC was 0.6953.
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
