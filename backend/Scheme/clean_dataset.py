import pandas as pd

file_path = "dataset.csv"
print(f"Loading {file_path} for cleaning...")
df = pd.read_csv(file_path)

mojibake_chars = ['ï', '¿', '½', 'ý', '']

def clean_text(val):
    if not isinstance(val, str):
        return val
    
    # Remove mojibake characters
    for char in mojibake_chars:
        val = val.replace(char, '')
        
    # Fix formula errors and escape characters
    # Sometimes it's loaded literally as #NAME?
    if val == '#NAME?':
        val = ''
    elif '#NAME?' in val:
        val = val.replace('#NAME?', '')
        
    # If starting with =- replace with - (it was probably a bullet point)
    if val.startswith('=-'):
        val = '-' + val[2:]
    
    # If starting with = (sometimes used to escape things in excel), remove it
    if val.startswith('='):
        val = val[1:]
        
    return val.strip()

# Apply cleaning to all object/string columns
for col in df.columns:
    if df[col].dtype == 'object':
        df[col] = df[col].apply(clean_text)

# Save back to CSV
df.to_csv(file_path, index=False)
print("Dataset cleaned and saved to dataset.csv")
