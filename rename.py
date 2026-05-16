import os
import glob

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    new_content = content.replace('Chip', 'Puce').replace('chip', 'puce').replace('CHIP', 'PUCE')

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

# Find all python and HTML files
search_paths = [
    'core/**/*.py',
    'api/**/*.py',
    'dashboard/**/*.py',
    'dashboard/templates/**/*.html',
    'seed_db.py',
    'manage.py',
    'config/**/*.py',
]

for pattern in search_paths:
    for filepath in glob.glob(pattern, recursive=True):
        if 'migrations' not in filepath and 'venv' not in filepath and 'rename.py' not in filepath:
            replace_in_file(filepath)

print("Done renaming files.")
