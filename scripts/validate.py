import os
import subprocess
import sys
import yaml
import jsonschema
from pathlib import Path
from jsonschema.exceptions import ValidationError

# Function to validate YAML files against a schema
def validate_yaml(directory, schema_file):
    try:
        with open(schema_file, 'r') as schema_fp:
            schema = json.load(schema_fp)

        has_yaml_files = False
        for yaml_file in directory.glob("*.yml"):
            has_yaml_files = True
            with open(yaml_file, 'r') as yaml_fp:
                data = yaml.safe_load(yaml_fp)
                jsonschema.validate(instance=data, schema=schema)
        
        if not has_yaml_files:
            print(f"No YAML files found in {directory}. Skipping...")
            return False

        return True
    except (FileNotFoundError, ValidationError) as e:
        print(f"Validation error in {directory}: {e}")
        return False

def main():
    # Check if Python dependencies are installed
    try:
        import yaml
        import jsonschema
    except ImportError as e:
        print(f"Missing required Python packages: {e.name}. Run 'pip install -r requirements.txt'")
        sys.exit(2)

    base_dir = Path("definitions")
    if not base_dir.exists():
        print(f"Definitions directory '{base_dir}' does not exist.")
        sys.exit(1)

    failed_dirs = []
    success = True

    # Loop through all directories starting with "v" that contain `.yml` files
    for dir_path in base_dir.glob("v*"):
        if dir_path.is_dir():
            yaml_files = list(dir_path.glob("*.yml"))
            if not yaml_files:
                print(f"No .yml files found in {dir_path}. Skipping...")
                continue
            
            schema_path = dir_path / "schema.json"
            if not schema_path.exists():
                print(f"Schema file missing: {schema_path}")
                failed_dirs.append(dir_path)
                success = False
                continue

            print(f"Validating {dir_path} against {schema_path}")
            if not validate_yaml(dir_path, schema_path):
                failed_dirs.append(dir_path)
                success = False

    if not success:
        print("\nFailed validations in the following directories:")
        for failed_dir in failed_dirs:
            print(f"- {failed_dir}")
        sys.exit(1)

    print("\nValidation successful!")
    sys.exit(0)

if __name__ == "__main__":
    main()
