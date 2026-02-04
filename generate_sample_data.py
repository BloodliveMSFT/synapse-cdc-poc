#!/usr/bin/env python3
"""
Sample Data Generator for Azure Synapse CDC POC Lab

This script generates synthetic CSV files for both scenarios:
- Scenario A: With timestamp column (customers_with_ts)
- Scenario B: Without timestamp column (products_no_ts)

Each scenario includes:
- Initial full dataset
- Multiple incremental versions with new/changed records
"""

import csv
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
OUTPUT_DIR = Path(__file__).parent / "sample-data"
SCENARIO_WITH_TS_DIR = OUTPUT_DIR / "scenario_with_timestamp"
SCENARIO_NO_TS_DIR = OUTPUT_DIR / "scenario_without_timestamp"

# Seed for reproducibility
random.seed(42)

# Sample data pools
FIRST_NAMES = [
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
    "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
    "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson"
]

CITIES = [
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia",
    "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville",
    "Fort Worth", "Columbus", "Charlotte", "Seattle", "Denver", "Boston"
]

STATES = [
    "NY", "CA", "IL", "TX", "AZ", "PA", "TX", "CA", "TX", "CA",
    "TX", "FL", "TX", "OH", "NC", "WA", "CO", "MA"
]

PRODUCT_CATEGORIES = ["Electronics", "Clothing", "Home & Garden", "Sports", "Books", "Toys"]
PRODUCT_ADJECTIVES = ["Premium", "Basic", "Pro", "Ultra", "Eco", "Smart", "Classic", "Modern"]
PRODUCT_NOUNS = ["Widget", "Gadget", "Device", "Tool", "Kit", "Set", "Pack", "Bundle"]


def generate_email(first_name, last_name, customer_id):
    """Generate a realistic email address."""
    domains = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "company.com"]
    return f"{first_name.lower()}.{last_name.lower()}{customer_id}@{random.choice(domains)}"


def generate_phone():
    """Generate a realistic US phone number."""
    return f"({random.randint(200, 999)}) {random.randint(200, 999)}-{random.randint(1000, 9999)}"


def format_timestamp(dt):
    """Format datetime as string."""
    return dt.strftime("%Y-%m-%d %H:%M:%S")


# ============================================================================
# SCENARIO A: With Timestamp Column (Customers)
# ============================================================================

def generate_customer_record(customer_id, timestamp):
    """Generate a single customer record."""
    first_name = random.choice(FIRST_NAMES)
    last_name = random.choice(LAST_NAMES)
    city_idx = random.randint(0, len(CITIES) - 1)
    
    return {
        "customer_id": customer_id,
        "first_name": first_name,
        "last_name": last_name,
        "email": generate_email(first_name, last_name, customer_id),
        "phone": generate_phone(),
        "city": CITIES[city_idx],
        "state": STATES[city_idx],
        "credit_limit": round(random.uniform(1000, 50000), 2),
        "last_updated_ts": format_timestamp(timestamp)
    }


def generate_customers_with_timestamp():
    """Generate customer data files with timestamp column."""
    print("\n" + "=" * 60)
    print("Generating Scenario A: Customers with Timestamp")
    print("=" * 60)
    
    os.makedirs(SCENARIO_WITH_TS_DIR, exist_ok=True)
    
    # Base timestamp
    base_time = datetime(2025, 1, 1, 10, 0, 0)
    
    # File 1: Initial full dataset (20 customers)
    print("\n[1/3] Generating initial dataset: customers_with_ts_initial.csv")
    customers = {}
    for i in range(1, 21):
        timestamp = base_time + timedelta(minutes=random.randint(0, 60))
        customers[i] = generate_customer_record(i, timestamp)
    
    file1_path = SCENARIO_WITH_TS_DIR / "customers_with_ts_initial.csv"
    write_csv(file1_path, customers.values())
    print(f"   Created: {file1_path.name} ({len(customers)} records)")
    
    # File 2: Incremental update 1 (5 new + 3 modified)
    print("\n[2/3] Generating incremental update 1: customers_with_ts_delta1.csv")
    delta1_time = base_time + timedelta(hours=2)
    delta1_records = []
    
    # Add 5 new customers (IDs 21-25)
    for i in range(21, 26):
        timestamp = delta1_time + timedelta(minutes=random.randint(0, 30))
        record = generate_customer_record(i, timestamp)
        delta1_records.append(record)
        customers[i] = record
    
    # Modify 3 existing customers (IDs 3, 7, 15)
    for cid in [3, 7, 15]:
        timestamp = delta1_time + timedelta(minutes=random.randint(0, 30))
        customers[cid]["credit_limit"] = round(customers[cid]["credit_limit"] * 1.2, 2)
        customers[cid]["last_updated_ts"] = format_timestamp(timestamp)
        delta1_records.append(customers[cid])
    
    file2_path = SCENARIO_WITH_TS_DIR / "customers_with_ts_delta1.csv"
    write_csv(file2_path, delta1_records)
    print(f"   Created: {file2_path.name} ({len(delta1_records)} records: 5 new, 3 modified)")
    
    # File 3: Incremental update 2 (3 new + 4 modified)
    print("\n[3/3] Generating incremental update 2: customers_with_ts_delta2.csv")
    delta2_time = base_time + timedelta(hours=4)
    delta2_records = []
    
    # Add 3 new customers (IDs 26-28)
    for i in range(26, 29):
        timestamp = delta2_time + timedelta(minutes=random.randint(0, 30))
        record = generate_customer_record(i, timestamp)
        delta2_records.append(record)
        customers[i] = record
    
    # Modify 4 existing customers (IDs 1, 10, 21, 25)
    for cid in [1, 10, 21, 25]:
        timestamp = delta2_time + timedelta(minutes=random.randint(0, 30))
        customers[cid]["city"] = random.choice(CITIES)
        customers[cid]["phone"] = generate_phone()
        customers[cid]["last_updated_ts"] = format_timestamp(timestamp)
        delta2_records.append(customers[cid])
    
    file3_path = SCENARIO_WITH_TS_DIR / "customers_with_ts_delta2.csv"
    write_csv(file3_path, delta2_records)
    print(f"   Created: {file3_path.name} ({len(delta2_records)} records: 3 new, 4 modified)")
    
    print(f"\nScenario A complete. Total customers in final state: {len(customers)}")


# ============================================================================
# SCENARIO B: Without Timestamp Column (Products)
# ============================================================================

def generate_product_record(product_id):
    """Generate a single product record (no timestamp)."""
    category = random.choice(PRODUCT_CATEGORIES)
    name = f"{random.choice(PRODUCT_ADJECTIVES)} {random.choice(PRODUCT_NOUNS)} {product_id}"
    
    return {
        "product_id": f"PROD-{product_id:04d}",
        "product_name": name,
        "category": category,
        "price": round(random.uniform(9.99, 999.99), 2),
        "stock_quantity": random.randint(0, 500),
        "supplier_id": f"SUP-{random.randint(1, 20):03d}",
        "is_active": random.choice(["true", "true", "true", "false"])  # 75% active
    }


def generate_products_without_timestamp():
    """Generate product data files without timestamp column."""
    print("\n" + "=" * 60)
    print("Generating Scenario B: Products without Timestamp")
    print("=" * 60)
    
    os.makedirs(SCENARIO_NO_TS_DIR, exist_ok=True)
    
    # File 1: Initial full dataset (25 products)
    print("\n[1/3] Generating initial dataset: products_no_ts_initial.csv")
    products = {}
    for i in range(1, 26):
        products[i] = generate_product_record(i)
    
    file1_path = SCENARIO_NO_TS_DIR / "products_no_ts_initial.csv"
    write_csv(file1_path, products.values())
    print(f"   Created: {file1_path.name} ({len(products)} records)")
    
    # File 2: Incremental update 1 (5 new + 4 modified)
    print("\n[2/3] Generating incremental update 1: products_no_ts_delta1.csv")
    delta1_records = []
    
    # Add 5 new products (IDs 26-30)
    for i in range(26, 31):
        record = generate_product_record(i)
        delta1_records.append(record)
        products[i] = record
    
    # Modify 4 existing products (IDs 2, 8, 15, 22) - change price and stock
    for pid in [2, 8, 15, 22]:
        products[pid]["price"] = round(products[pid]["price"] * random.uniform(0.8, 1.3), 2)
        products[pid]["stock_quantity"] = random.randint(0, 500)
        delta1_records.append(products[pid])
    
    file2_path = SCENARIO_NO_TS_DIR / "products_no_ts_delta1.csv"
    write_csv(file2_path, delta1_records)
    print(f"   Created: {file2_path.name} ({len(delta1_records)} records: 5 new, 4 modified)")
    
    # File 3: Incremental update 2 (4 new + 6 modified)
    print("\n[3/3] Generating incremental update 2: products_no_ts_delta2.csv")
    delta2_records = []
    
    # Add 4 new products (IDs 31-34)
    for i in range(31, 35):
        record = generate_product_record(i)
        delta2_records.append(record)
        products[i] = record
    
    # Modify 6 existing products (IDs 1, 5, 12, 26, 28, 30)
    for pid in [1, 5, 12, 26, 28, 30]:
        products[pid]["price"] = round(products[pid]["price"] * random.uniform(0.9, 1.2), 2)
        products[pid]["stock_quantity"] = random.randint(0, 500)
        products[pid]["is_active"] = random.choice(["true", "false"])
        delta2_records.append(products[pid])
    
    file3_path = SCENARIO_NO_TS_DIR / "products_no_ts_delta2.csv"
    write_csv(file3_path, delta2_records)
    print(f"   Created: {file3_path.name} ({len(delta2_records)} records: 4 new, 6 modified)")
    
    print(f"\nScenario B complete. Total products in final state: {len(products)}")


def write_csv(filepath, records):
    """Write records to CSV file."""
    records_list = list(records)
    if not records_list:
        return
    
    fieldnames = records_list[0].keys()
    with open(filepath, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records_list)


def main():
    """Main entry point."""
    print("=" * 60)
    print("Azure Synapse CDC POC - Sample Data Generator")
    print("=" * 60)
    
    # Generate both scenarios
    generate_customers_with_timestamp()
    generate_products_without_timestamp()
    
    print("\n" + "=" * 60)
    print("Sample Data Generation Complete!")
    print("=" * 60)
    print(f"\nOutput directory: {OUTPUT_DIR}")
    print("\nGenerated files:")
    print("\nScenario A (With Timestamp):")
    for f in sorted(SCENARIO_WITH_TS_DIR.glob("*.csv")):
        print(f"  - {f.name}")
    print("\nScenario B (Without Timestamp):")
    for f in sorted(SCENARIO_NO_TS_DIR.glob("*.csv")):
        print(f"  - {f.name}")
    
    print("\n" + "=" * 60)
    print("Usage Instructions:")
    print("=" * 60)
    print("""
1. For Scenario A (timestamp-based CDC):
   - Upload customers_with_ts_initial.csv first
   - Run the notebook
   - Upload customers_with_ts_delta1.csv
   - Run the notebook again to see incremental processing
   - Repeat with customers_with_ts_delta2.csv

2. For Scenario B (hash-based CDC):
   - Upload products_no_ts_initial.csv first
   - Run the notebook
   - Upload products_no_ts_delta1.csv
   - Run the notebook again to see incremental processing
   - Repeat with products_no_ts_delta2.csv
""")


if __name__ == "__main__":
    main()
