#!/usr/bin/env python

"""
Merge model-selection hyperparameter JSON files and generate a long-format CSV.
"""

import argparse
import csv
import json
from pathlib import Path


REQUIRED_FIELDS = {
    "dataset",
    "method",
    "analysis_stage",
    "parameters",
}


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Merge selected-hyperparameter JSON files and convert the "
            "parameters into a long-format CSV."
        )
    )

    parser.add_argument(
        "--inputs",
        nargs="+",
        required=True,
        help="Input selected-hyperparameter JSON files."
    )

    parser.add_argument(
        "--json-output",
        default="selected_hyperparameters.json",
        help="Path for the merged JSON output."
    )

    parser.add_argument(
        "--csv-output",
        default="selected_hyperparameters.csv",
        help="Path for the flattened CSV output."
    )

    return parser.parse_args()


def read_hyperparameter_json(path):
    path = Path(path)

    with path.open("r", encoding="utf-8") as handle:
        result = json.load(handle)

    missing_fields = REQUIRED_FIELDS.difference(result)

    if missing_fields:
        missing = ", ".join(sorted(missing_fields))
        raise ValueError(
            f"{path}: missing required fields: {missing}"
        )

    if not isinstance(result["parameters"], dict):
        raise TypeError(
            f"{path}: 'parameters' must be a JSON object"
        )

    return result


def value_type(value):
    """
    Return a simple cross-language description of a JSON value.
    """

    if value is None:
        return "null"

    if isinstance(value, bool):
        return "boolean"

    if isinstance(value, int):
        return "integer"

    if isinstance(value, float):
        return "numeric"

    if isinstance(value, str):
        return "string"

    if isinstance(value, list):
        return "array"

    if isinstance(value, dict):
        return "object"

    return type(value).__name__


def csv_value(value):
    """
    Convert a scalar JSON value into a CSV-safe representation.
    """

    if value is None:
        return ""

    if isinstance(value, bool):
        return str(value).lower()

    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)

    return value


def flatten_value(parameter_path, value):
    """
    Recursively flatten a nested parameter value.

    Examples
    --------
    keepX = {
        "genomics": [50, 25],
        "proteomics": [20, 20]
    }

    becomes:

    keepX.genomics[1] = 50
    keepX.genomics[2] = 25
    keepX.proteomics[1] = 20
    keepX.proteomics[2] = 20
    """

    if isinstance(value, dict):
        if not value:
            yield parameter_path, value
            return

        for key in sorted(value):
            child_path = f"{parameter_path}.{key}"
            yield from flatten_value(child_path, value[key])

        return

    if isinstance(value, list):
        if not value:
            yield parameter_path, value
            return

        # Use one-based indexing because these usually represent
        # latent components or ordered model layers.
        for index, item in enumerate(value, start=1):
            child_path = f"{parameter_path}[{index}]"
            yield from flatten_value(child_path, item)

        return

    yield parameter_path, value


def make_parameter_rows(run):
    selection = run.get("selection", {})
    rows = []

    for parameter, record in run["parameters"].items():
        if not isinstance(record, dict):
            raise TypeError(
                f"{run['dataset']}/{run['method']}/{parameter}: "
                "parameter record must be a JSON object"
            )

        if "value" not in record:
            raise ValueError(
                f"{run['dataset']}/{run['method']}/{parameter}: "
                "parameter record is missing 'value'"
            )

        treatment = record.get("treatment", "unknown")

        for parameter_path, selected_value in flatten_value(
            parameter,
            record["value"]
        ):
            rows.append({
                "dataset": run["dataset"],
                "method": run["method"],
                "analysis_stage": run["analysis_stage"],
                "parameter_path": parameter_path,
                "selected_value": csv_value(selected_value),
                "treatment": treatment,
                # "selection_metric": selection.get("metric", ""),
                # "cv_type": selection.get("cv_type", ""),
                # "n_iter": selection.get("n_iter", ""),
                # "random_state": selection.get("random_state", ""),
                # "best_cv_score": selection.get("best_cv_score", ""),
            })

    return rows


def write_merged_json(runs, output_path):
    merged_result = {
        "schema_version": "1.0",
        "analysis_stage": "model_selection",
        "n_runs": len(runs),
        "runs": runs,
    }

    with Path(output_path).open("w", encoding="utf-8") as handle:
        json.dump(
            merged_result,
            handle,
            indent=2,
            ensure_ascii=False
        )


def write_long_csv(rows, output_path):
    columns = [
        "dataset",
        "method",
        "analysis_stage",
        "parameter_path",
        "selected_value",
        "treatment",
        # "selection_metric",
        # "cv_type",
        # "n_iter",
        # "random_state",
        # "best_cv_score",
    ]

    with Path(output_path).open(
        "w",
        encoding="utf-8",
        newline=""
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def main():
    args = parse_args()

    runs = [
        read_hyperparameter_json(path)
        for path in args.inputs
    ]

    # Deterministic ordering makes outputs easier to compare with git diff.
    runs.sort(
        key=lambda run: (
            str(run.get("dataset", "")),
            str(run.get("method", "")),
        )
    )

    rows = []

    for run in runs:
        rows.extend(make_parameter_rows(run))

    rows.sort(
        key=lambda row: (
            row["dataset"],
            row["method"],
            row["parameter_path"],
        )
    )

    write_merged_json(
        runs=runs,
        output_path=args.json_output
    )

    write_long_csv(
        rows=rows,
        output_path=args.csv_output
    )

    print(
        f"Merged {len(runs)} model-selection runs "
        f"into {len(rows)} parameter rows."
    )


if __name__ == "__main__":
    main()