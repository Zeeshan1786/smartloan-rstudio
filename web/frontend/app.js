"use strict";

const controls = [
  ["ApplicantIncome", "Applicant income", 0],
  ["CoapplicantIncome", "Co-applicant income", 0],
  ["LoanAmount", "Loan amount (thousands)", 0.01],
  ["Loan_Amount_Term", "Term (months)", 1],
  ["Credit_History", "Credit history flag", [["1", "1 — Meets criteria"], ["0", "0 — Does not meet criteria"]]],
  ["Property_Area", "Property area", ["Rural", "Semiurban", "Urban"]],
  ["Education", "Education", ["Graduate", "Not Graduate"]],
  ["Self_Employed", "Self employed", ["No", "Yes"]],
  ["Dependents", "Dependents", ["0", "1", "2", "3+"]],
  ["Married", "Married", ["No", "Yes"]],
  ["Gender", "Gender", ["Female", "Male"]]
];
const chartNames = {
  "01_loan_status.png": "Recorded loan outcomes",
  "02_income.png": "Applicant income",
  "03_loan_amount.png": "Loan amounts",
  "04_education.png": "Outcomes by education",
  "05_credit_history.png": "Outcomes by credit history",
  "06_correlation.png": "Feature correlations",
  "07_confusion_forest.png": "Random forest confusion matrix",
  "07_confusion_logistic.png": "Logistic regression confusion matrix",
  "07_confusion_tree.png": "Decision tree confusion matrix",
  "08_test_roc.png": "ROC curves",
  "09_model_comparison.png": "Model comparison",
  "10_forest_importance.png": "Random forest feature importance",
  "11_decision_tree.png": "Decision tree diagram"
};
const get = (id) => document.getElementById(id);
const pct = (v) => v === null || v === undefined || !Number.isFinite(Number(v))
  ? "—" : (Number(v) * 100).toFixed(1) + "%";
const form = get("form");
for (const [key, label, rule] of controls) {
  const wrap = document.createElement("label");
  wrap.textContent = label;
  const input = document.createElement(Array.isArray(rule) ? "select" : "input");
  input.name = key;
  if (Array.isArray(rule)) {
    input.add(new Option("Unknown", ""));
    for (const item of rule) {
      const [value, text] = Array.isArray(item) ? item : [item, item];
      input.add(new Option(text, value));
    }
  } else {
    input.type = "number";
    input.min = String(rule);
    input.step = key === "Loan_Amount_Term" ? "1" : "any";
    input.placeholder = "Unknown";
  }
  wrap.append(input);
  get("fields").append(wrap);
}

async function api(path, init) {
  const response = await fetch(path, init);
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error || "The R API returned an error.");
  return payload;
}
function showResult(title, text, result) {
  get("outcome").textContent = title;
  get("details").textContent = text;
  get("result").dataset.outcome = result?.predicted_status ?? "";
  get("live-charts").hidden = !result;
  if (result) {
    showBars("score-chart", [["Submitted profile", result]], result.threshold);
    showBars("scenario-chart", result.scenarios.map((scenario) => [
      "Credit history = " + scenario.credit_history, scenario
    ]), result.threshold);
  }
}
function showBars(id, rows, threshold) {
  const chart = get(id);
  chart.replaceChildren();
  for (const [label, result] of rows) {
    const row = document.createElement("div");
    row.className = "score-row";
    const title = document.createElement("div");
    title.className = "score-label";
    const name = document.createElement("span");
    name.textContent = label;
    const value = document.createElement("span");
    value.textContent = pct(result.score_y) + " · " + result.predicted_status;
    title.append(name, value);
    const track = document.createElement("div");
    track.className = "score-track";
    track.setAttribute("aria-hidden", "true");
    const bar = document.createElement("div");
    bar.className = "score-bar";
    bar.dataset.outcome = result.predicted_status;
    bar.style.width = Number(result.score_y) * 100 + "%";
    const marker = document.createElement("span");
    marker.className = "score-cutoff";
    marker.style.left = Number(threshold) * 100 + "%";
    track.append(bar, marker);
    row.append(title, track);
    chart.append(row);
  }
  const scale = document.createElement("div");
  scale.className = "scale";
  for (const label of ["0%", "Marker: " + pct(threshold) + " cutoff", "100%"]) {
    const item = document.createElement("span");
    item.textContent = label;
    scale.append(item);
  }
  chart.append(scale);
}
function displayMetrics(project, mode) {
  get("test-toggle").setAttribute("aria-pressed", String(mode === "test"));
  get("val-toggle").setAttribute("aria-pressed", String(mode === "validation"));
  get("caption").textContent = mode === "test" ? "Held-out test metrics" : "Validation metrics";
  get("metrics").replaceChildren();
  for (const result of project[mode]) {
    const row = document.createElement("tr");
    if (result.Model === project.model) row.classList.add("selected");
    const name = document.createElement("th");
    name.scope = "row";
    name.textContent = result.Model + (result.Model === project.model ? " · Selected" : "");
    row.append(name);
    for (const field of ["Threshold", "Accuracy", "Precision", "Recall", "Specificity", "Balanced_Accuracy", "F1", "ROC_AUC"]) {
      const cell = document.createElement("td");
      cell.textContent = field === "ROC_AUC" && result[field] != null ? Number(result[field]).toFixed(3) : pct(result[field]);
      row.append(cell);
    }
    get("metrics").append(row);
  }
}
function showCharts(files) {
  for (const file of files) {
    if (!Object.hasOwn(chartNames, file)) continue;
    const label = chartNames[file];
    const url = "/charts/" + encodeURIComponent(file);
    const button = document.createElement("button");
    button.type = "button";
    const img = document.createElement("img");
    img.src = url;
    img.loading = "lazy";
    img.alt = "";
    button.append(img, label);
    button.addEventListener("click", () => {
      get("chart-name").textContent = label;
      get("chart").src = url;
      get("chart").alt = label;
      get("viewer").showModal();
    });
    get("gallery").append(button);
  }
}

let revision = 0;
form.addEventListener("input", () => {
  revision++;
  showResult("Profile changed", "Run prediction to update the result and charts.");
});
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const requestRevision = ++revision;
  get("submit").disabled = true;
  showResult("Running the model", "Waiting for the R API.");
  try {
    const profile = Object.fromEntries([...new FormData(form)].map(([key, value]) => [key, value || null]));
    const result = await api("/api/predict", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(profile)
    });
    if (requestRevision !== revision) return;
    const title = result.predicted_status === "Y" ? "Y · Predicted approved" : "N · Predicted not approved";
    const filled = result.imputed_fields.map((key) => controls.find(([name]) => name === key)?.[1] ?? key);
    const note = filled.length ? "\nTraining defaults applied to: " + filled.join(", ") + "." : "";
    showResult(title, result.model + " · Score for Y: " + pct(result.score_y) +
      "\nDecision threshold: " + pct(result.threshold) + "." + note, result);
  } catch (error) {
    if (requestRevision === revision) showResult("Prediction unavailable", error.message);
  } finally {
    get("submit").disabled = false;
  }
});

api("/api/project").then((project) => {
  get("connection").textContent = "R API connected";
  get("dataset").textContent = project.dataset;
  get("rows").textContent = Number(project.rows).toLocaleString();
  get("model").textContent = project.model;
  get("split").textContent = project.splits.map((row) => row.Split + ": " + row.Records).join(" · ");
  const loadExample = (example) => {
    revision++;
    for (const [key] of controls) form.elements.namedItem(key).value = example[key] ?? "";
    showResult("Profile loaded", "Select Run prediction to score this example.");
  };
  for (const [index, example] of project.examples.slice(0, 2).entries()) {
    const button = get("example" + index);
    button.addEventListener("click", () => loadExample(example));
    button.disabled = false;
  }
  if (project.examples.length) loadExample(project.examples[0]);
  get("submit").disabled = false;
  get("test-toggle").addEventListener("click", () => displayMetrics(project, "test"));
  get("val-toggle").addEventListener("click", () => displayMetrics(project, "validation"));
  displayMetrics(project, "test");
  showCharts(project.charts);
}).catch((error) => {
  get("connection").textContent = "R API unavailable";
  showResult("Unable to load SmartLoan", error.message + " Start RunWeb.R and reload.");
});
