import pandas as pd

# Load dataset
file_path = "dataset.csv"
print(f"Loading {file_path} for cleaning...")
df = pd.read_csv(file_path)

# Count initial issues
mojibake_chars = ['ï¿½ï¿½ï¿½', 'ýýý', 'ï¿½', 'ý']
print("Analyzing columns for mojibake and formula errors...")

def count_formula_errors(series):
    if series.dtype != 'object': return 0
    # Formula starts with =, -, +, @ and might result in #NAME?
    return series.astype(str).str.startswith('=-').sum() + (series == '#NAME?').sum()

for col in df.columns:
    if df[col].dtype == 'object':
        formula_errs = count_formula_errors(df[col])
        if formula_errs > 0:
            print(f"Column '{col}' has {formula_errs} formula errors.")
            
        for char in mojibake_chars:
            mojibake_errs = df[col].astype(str).str.contains(char, regex=False).sum()
            if mojibake_errs > 0:
                print(f"Column '{col}' has {mojibake_errs} occurrences of {char}.")

# Clean the dataset
print("Cleaning data...")
# Replace mojibake with standard character or empty string, let's use standard placeholders:
# In many cases 'ï¿½ï¿½ï¿½' or 'ýýý' replaced a hyphen, quote, or rupee symbol.
# Since it's hard to guess perfectly, replacing with a space or empty string or just a generic hyphen/quote might be best, 
# but usually replacing with empty string '' or a single quote "'" is safe if we don't know the exact encoding. 
# We'll replace 'ï¿½ï¿½ï¿½' with '' and 'ýýý' with ''. Sometimes it's a rupee symbol so ' Rs. ' 
# Let's see the context first.
