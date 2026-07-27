"""
Day 1 - Live NAV Fetch Script
Fetches live NAV data for key mutual fund schemes from mfapi.in
and saves each as a raw CSV file.
"""

import os
import requests
import pandas as pd

RAW_DATA_DIR = "data/raw"

# AMFI scheme codes for key funds
SCHEMES = {
    "HDFC_Top_100_Direct": 125497,
    "SBI_Bluechip": 119551,
    "ICICI_Bluechip": 120503,
    "Nippon_Large_Cap": 118632,
    "Axis_Bluechip": 119092,
    "Kotak_Bluechip": 120841,
}


def fetch_nav(scheme_code):
    """Fetch NAV history for a single scheme code from mfapi.in."""
    url = f"https://api.mfapi.in/mf/{scheme_code}"
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    return response.json()


def save_nav_to_csv(scheme_name, scheme_code, data):
    """Convert the API JSON response into a CSV file."""
    os.makedirs(RAW_DATA_DIR, exist_ok=True)

    nav_data = data.get("data", [])
    if not nav_data:
        print(f"No NAV data found for {scheme_name} ({scheme_code})")
        return

    df = pd.DataFrame(nav_data)
    df["scheme_name"] = scheme_name
    df["scheme_code"] = scheme_code

    file_path = os.path.join(RAW_DATA_DIR, f"{scheme_name}_nav.csv")
    df.to_csv(file_path, index=False)
    print(f"Saved: {file_path} ({len(df)} rows)")


def fetch_all_schemes():
    """Loop through all schemes, fetch NAV data, and save to CSV."""
    for scheme_name, scheme_code in SCHEMES.items():
        try:
            print(f"Fetching {scheme_name} ({scheme_code})...")
            data = fetch_nav(scheme_code)
            save_nav_to_csv(scheme_name, scheme_code, data)
        except Exception as e:
            print(f"Error fetching {scheme_name}: {e}")


if __name__ == "__main__":
    fetch_all_schemes()
