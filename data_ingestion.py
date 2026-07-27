"""
Day 1 - Data Ingestion Script
Loads all raw CSV datasets, inspects their structure, and validates
AMFI scheme codes between fund_master and nav_history.
"""

import os
import pandas as pd

RAW_DATA_DIR = "data/raw"


def load_all_csv_files(folder_path=RAW_DATA_DIR):
    """Load every CSV file in the given folder into a dict of DataFrames."""
    datasets = {}
    if not os.path.exists(folder_path):
        print(f"Folder not found: {folder_path}")
        return datasets

    for file_name in os.listdir(folder_path):
        if file_name.endswith(".csv"):
            file_path = os.path.join(folder_path, file_name)
            key = file_name.replace(".csv", "")
            try:
                df = pd.read_csv(file_path)
                datasets[key] = df
                print(f"\nLoaded: {file_name}")
                print(f"Shape: {df.shape}")
                print(f"Dtypes:\n{df.dtypes}")
                print(f"Head:\n{df.head()}")
            except Exception as e:
                print(f"Error loading {file_name}: {e}")
    return datasets


def explore_fund_master(datasets):
    """Print unique fund houses, categories, sub-categories, and risk grades."""
    fund_master = datasets.get("fund_master")
    if fund_master is None:
        print("fund_master.csv not found in raw data.")
        return

    for col in ["fund_house", "category", "sub_category", "risk_grade"]:
        if col in fund_master.columns:
            print(f"\nUnique {col}:")
            print(fund_master[col].dropna().unique())


def validate_amfi_codes(datasets):
    """Confirm every AMFI code in fund_master exists in nav_history."""
    fund_master = datasets.get("fund_master")
    nav_history = datasets.get("nav_history")

    if fund_master is None or nav_history is None:
        print("fund_master or nav_history not found. Skipping validation.")
        return

    code_col_master = "amfi_code" if "amfi_code" in fund_master.columns else "scheme_code"
    code_col_nav = "amfi_code" if "amfi_code" in nav_history.columns else "scheme_code"

    master_codes = set(fund_master[code_col_master].unique())
    nav_codes = set(nav_history[code_col_nav].unique())

    missing_codes = master_codes - nav_codes

    print("\n--- Data Quality Summary ---")
    print(f"Total codes in fund_master: {len(master_codes)}")
    print(f"Total codes in nav_history: {len(nav_codes)}")
    print(f"Codes missing from nav_history: {len(missing_codes)}")
    if missing_codes:
        print(f"Missing codes: {missing_codes}")


if __name__ == "__main__":
    datasets = load_all_csv_files()
    explore_fund_master(datasets)
    validate_amfi_codes(datasets)
