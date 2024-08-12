import pandas as pd


def process_response(y_series, convert_to="numeric"):
    """
    Args:

    y_series      Pandas series containing response
    convert_to    Type of casting to do for numeric or string
    """
    # Validate the input type
    if not isinstance(y_series, pd.Series):
        raise TypeError("Response must be a pandas Series.")

    # Ensure there are exactly two unique labels
    unique_labels = set(y_series.unique())
    if len(unique_labels) != 2:
        raise ValueError("Response should contain exactly two classes.")

    # Define mappings for conversions
    # TODO: This could be optimized?, right now is like a brute force
    label_mappings = {
        "numeric": {"yes": 1, "no": 0, "1": 1, "0": 0, "1.0": 1, "0.0": 0, 1: 1, 0: 0, 1.0: 1, 0.0: 0},
        "categorical": {1: "yes", 0: "no", 1.0: "yes", 0.0: "no", "1": "yes", "0": "no", "1.0": "yes", "0.0": "no"}
    }

    # Validate the conversion type
    if convert_to not in label_mappings:
        raise ValueError("Invalid convert_to value. Use 'numeric' or 'categorical'.")

    # Ensure all labels are recognized binary formats
    if not all(label in label_mappings[convert_to] for label in unique_labels):
        raise ValueError(f"Unrecognized labels in response: {unique_labels}")


    # TODO: this part here below have a lot of redundant stuff
    # Replace values based on the desired conversion
    y_series_new = y_series.replace(label_mappings[convert_to])

     # Convert the data type
    if convert_to == "numeric":
        y_series_new = y_series_new.astype(int)
        expected_values = {1, 0}
    elif convert_to == "categorical":
        y_series_new = y_series_new.astype(str)
        expected_values = {"yes", "no"}

    # Ensure correct final mapping
    if set(y_series_new.unique()) != expected_values:
        raise ValueError("Final mapped values are incorrect.")

    return y_series_new
