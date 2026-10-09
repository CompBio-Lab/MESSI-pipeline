"""Dispatch survival models by name.

Returns a *fitted* SurvivalPipeline (scaler + scikit-survival model) exposing
predict() (risk score) and predict_survival_function() (S(t)).

Available models:
  - coxnet : elastic-net Cox (CoxnetSurvivalAnalysis); alpha tuned by inner
             CV on the training fold maximizing Harrell's C-index
  - rsf    : Random Survival Forest
  - gbm    : Gradient Boosting survival model (CoxPH loss)
"""

import numpy as np
from sklearn.model_selection import GridSearchCV, StratifiedKFold
from sklearn.preprocessing import StandardScaler
from sksurv.ensemble import RandomSurvivalForest, GradientBoostingSurvivalAnalysis
from sksurv.linear_model import CoxnetSurvivalAnalysis
from sksurv.metrics import concordance_index_censored

from manual_set_seed import set_seed

SEED = 42

# Horizons (days) at which S(t) is predicted downstream
SURV_HORIZONS = [365, 548, 730, 1095, 1461, 1826] # TODO: might need to explain where this is from


class SurvivalPipeline:
    """Minimal scaler + survival-model wrapper.

    Exposes the two calls the MESSI predict step needs:
      - predict(X)                  -> risk score (higher = riskier)
      - predict_survival_function(X)-> list of StepFunction S(t)
    """

    def __init__(self, model, scaler=None):
        self.model = model
        self.scaler = scaler

    def _X(self, X):
        return self.scaler.transform(X) if self.scaler is not None else X

    def predict(self, X):
        return self.model.predict(self._X(X))

    def predict_survival_function(self, X, **kwargs):
        return self.model.predict_survival_function(self._X(X), **kwargs)

    def predict_cumulative_hazard_function(self, X, **kwargs):
        return self.model.predict_cumulative_hazard_function(self._X(X), **kwargs)


def cindex_scorer(estimator, X, y):
    """Harrell's C-index scorer usable by sklearn GridSearchCV with survival y."""
    lp = estimator.predict(X)
    return concordance_index_censored(y["status"], y["time"], lp)[0]


def build_coxnet(X, y, l1_ratio=0.5, n_alphas=10, inner_folds=3):
    """Elastic-net Cox with inner-CV alpha selection on the training fold."""
    set_seed(SEED)
    # Alpha path from the training fold (same convention as cv.glmnet)
    path_model = CoxnetSurvivalAnalysis(l1_ratio=l1_ratio)
    path_model.fit(X, y)
    alphas = np.asarray(path_model.alphas_)
    # Keep a log-spaced subset of the path (down to max/100)
    alphas = np.unique(np.logspace(
        np.log10(alphas.max()),
        np.log10(max(alphas.min(), alphas.max() / 100)),
        n_alphas,
    ))
    # stratify inner CV on the event indicator; shrink folds if events are scarce
    # (sklearn StratifiedKFold cannot stratify on structured arrays directly)
    n_minority = int(min(y["status"].sum(), (~y["status"]).sum()))
    inner_folds = max(2, min(inner_folds, n_minority))
    skf = StratifiedKFold(n_splits=inner_folds, shuffle=True, random_state=SEED)
    cv_splits = list(skf.split(X, y["status"]))

    # Manual inner CV: per-fold try/except so numerically unstable alphas
    # (small end of the path) get NaN instead of aborting the search
    mean_scores = {}
    for a in alphas:
        scores = []
        for tr_i, va_i in cv_splits:
            try:
                m = _make_coxnet_pipe(l1_ratio).set_params(coxnet__alphas=[a])
                m.fit(X.iloc[tr_i], y[tr_i])
                scores.append(cindex_scorer(m, X.iloc[va_i], y[va_i]))
            except (ArithmeticError, ValueError):
                scores.append(np.nan)
        mean_scores[a] = np.nanmean(scores) if np.any(~np.isnan(scores)) else np.nan

    # Refit on the full training fold, best CV score first; skip alphas whose
    # refit fails numerically or yields a degenerate all-zero model
    ranked = sorted(alphas, key=lambda a: -np.nan_to_num(mean_scores[a], nan=-np.inf))
    for a in ranked:
        if np.isnan(mean_scores[a]):
            continue
        try:
            final = _make_coxnet_pipe(l1_ratio).set_params(coxnet__alphas=[a])
            final.fit(X, y)
            lp = final.predict(X)
            if np.std(lp) < 1e-10:
                continue  # fully regularized (all coefficients zero)
            return SurvivalPipeline(model=final.named_steps["coxnet"],
                                    scaler=final.named_steps["scale"])
        except (ArithmeticError, ValueError):
            continue
    raise RuntimeError("coxnet refit failed for all candidate alphas")


from sklearn.pipeline import Pipeline as _SkPipeline


def _make_coxnet_pipe(l1_ratio):
    return _SkPipeline([
        ("scale", StandardScaler()),
        # fit_baseline_model=True enables predict_survival_function (Breslow)
        ("coxnet", CoxnetSurvivalAnalysis(
            l1_ratio=l1_ratio, alphas=[1.0], fit_baseline_model=True)),
    ])


def build_rsf(X, y):
    set_seed(SEED)
    model = RandomSurvivalForest(
        n_estimators=200,
        min_samples_leaf=10,
        max_features=0.2,
        n_jobs=-1,
        random_state=SEED,
    )
    model.fit(X, y)
    return SurvivalPipeline(model=model)  # trees need no scaling


def build_gbm(X, y):
    set_seed(SEED)
    model = GradientBoostingSurvivalAnalysis(
        loss="coxph",
        n_estimators=200,
        learning_rate=0.1,
        subsample=0.8,
        max_features=0.2,
        random_state=SEED,
    )
    model.fit(X, y)
    return SurvivalPipeline(model=model)  # trees need no scaling


BUILDERS = {
    "coxnet": build_coxnet,
    "rsf": build_rsf,
    "gbm": build_gbm,
}


def load_survival_model_class(model_name):
    """Return the builder callable for a model name (raises on unknown names)."""
    key = model_name.lower().replace(" ", "_").replace("-", "_")
    if key not in BUILDERS:
        raise ValueError(
            f"Unknown survival model '{model_name}'. Available: {sorted(BUILDERS)}"
        )
    return BUILDERS[key]
