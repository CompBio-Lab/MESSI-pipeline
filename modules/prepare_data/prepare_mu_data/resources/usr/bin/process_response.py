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

    # Normalize string labels to lowercase
    y_series = y_series.apply(
        lambda x: x.lower() if isinstance(x, str) else x
    )
    # Ensure there are exactly two unique labels
    unique_labels = set(y_series.unique())
    if len(unique_labels) != 2:
        raise ValueError("Response should contain exactly two classes.")

    # Define mappings for conversions
    # TODO: This could be optimized?, right now is like a brute force
    numeric_mapping = {
        "yes": 1, "no": 0,
        "1": 1, "0": 0,
        "1.0": 1, "0.0": 0,
        1: 1, 0: 0,
        1.0: 1, 0.0: 0
    }

    categorical_mapping = {
        1: "yes", 0: "no",
        1.0: "yes", 0.0: "no",
        "1": "yes", "0": "no",
        "1.0": "yes", "0.0": "no"
    }

    # TODO: this part here below have a lot of redundant stuff
    # Replace values based on the desired conversion
    # Determine the appropriate mapping based on the conversion type
    if convert_to == "numeric":
        mapping = numeric_mapping
        expected_values = {1, 0}
    elif convert_to == "categorical":
        mapping = categorical_mapping
        expected_values = {"yes", "no"}
    else:
        raise ValueError("Invalid conversion type specified. Use 'numeric' or 'categorical'.")

    # Check if the series is already in the expected format
    if set(y_series) == expected_values:
        return y_series.astype(int) if convert_to == "numeric" else y_series.astype(str)

    # Validate that all labels are recognized
    if not all(label in mapping for label in unique_labels):
        raise ValueError(f"Unrecognized labels in response: {unique_labels}")

    # Map labels to the desired format
    y_series_new = y_series.replace(mapping)

    # Ensure the conversion results in the expected values
    assert set(y_series_new.unique()) == expected_values
    return y_series_new
