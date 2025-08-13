#!/usr/bin/env python3
"""
JSON Schema validation for Prowlarr indexer definitions.
Alternative to Node.js-based validation using Python.
"""

import sys
import json
import os
import glob
from pathlib import Path
import argparse
import yaml

# Constants
DEFAULT_DEFINITIONS_DIR = "definitions"
SCHEMA_FILENAME = "schema.json"
YAML_EXTENSIONS = ["*.yml", "*.yaml"]

try:
    from jsonschema import validate, ValidationError, Draft201909Validator
    from jsonschema.validators import validator_for
except ImportError:
    print("Error: jsonschema package is required. Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)

def load_json_schema(schema_path):
    """Load and return JSON schema from file."""
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading schema {schema_path}: {e}", file=sys.stderr)
        return None

def convert_numeric_keys_to_strings(obj):
    """Recursively convert numeric keys to strings to fix jsonschema regex issues."""
    if isinstance(obj, dict):
        new_dict = {}
        for key, value in obj.items():
            # Convert numeric keys to strings
            new_key = str(key) if isinstance(key, int) else key
            new_dict[new_key] = convert_numeric_keys_to_strings(value)
        return new_dict
    elif isinstance(obj, list):
        return [convert_numeric_keys_to_strings(item) for item in obj]
    else:
        return obj

def load_yaml_file(yaml_path):
    """Load and return YAML file content."""
    try:
        with open(yaml_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            # Convert numeric keys to strings to avoid jsonschema regex issues
            return convert_numeric_keys_to_strings(data)
    except (yaml.YAMLError, FileNotFoundError) as e:
        print(f"Error loading YAML {yaml_path}: {e}", file=sys.stderr)
        return None

def validate_file_against_schema(yaml_path, schema):
    """Validate a single YAML file against the schema."""
    data = load_yaml_file(yaml_path)
    if data is None:
        return False, f"Failed to load YAML file: {yaml_path}"
    
    try:
        # Use Draft 2019-09 validator to match the original implementation
        validator_class = validator_for(schema)
        validator_class.check_schema(schema)
        validator = validator_class(schema)
        validator.validate(data)
        return True, None
    except ValidationError as e:
        return False, f"Validation error in {yaml_path}: {str(e)}"
    except Exception as e:
        return False, f"Error validating {yaml_path}: {str(e)}"

def validate_directory(definitions_dir):
    """Validate all YAML files in a definitions directory."""
    success = True
    error_count = 0
    total_files = 0
    
    # Find all version directories
    version_dirs = glob.glob(os.path.join(definitions_dir, "v*"))
    version_dirs.sort()
    
    if not version_dirs:
        print(f"No version directories found in {definitions_dir}")
        return False
    
    for version_dir in version_dirs:
        if not os.path.isdir(version_dir):
            continue
            
        print(f"Validating {version_dir}")
        
        schema_path = os.path.join(version_dir, SCHEMA_FILENAME)
        if not os.path.exists(schema_path):
            print(f"Warning: No schema.json found in {version_dir}")
            continue
            
        schema = load_json_schema(schema_path)
        if schema is None:
            print(f"Error: Failed to load schema from {schema_path}")
            success = False
            continue
            
        # Find all YAML files in this version directory
        yaml_files = []
        for extension in YAML_EXTENSIONS:
            yaml_files.extend(glob.glob(os.path.join(version_dir, extension)))
        
        if not yaml_files:
            print(f"No YAML files found in {version_dir}")
            continue
            
        for yaml_file in sorted(yaml_files):
            total_files += 1
            is_valid, error_msg = validate_file_against_schema(yaml_file, schema)
            
            if not is_valid:
                print(f"FAIL: {error_msg}")
                success = False
                error_count += 1
            else:
                print(f"PASS: {os.path.basename(yaml_file)}")
    
    print(f"\nValidation Summary:")
    print(f"Total files: {total_files}")
    print(f"Errors: {error_count}")
    print(f"Success: {total_files - error_count}")
    
    return success

def validate_single_file(yaml_file, schema_file):
    """Validate a single file against a schema."""
    schema = load_json_schema(schema_file)
    if schema is None:
        return False
    
    is_valid, error_msg = validate_file_against_schema(yaml_file, schema)
    if not is_valid:
        print(error_msg, file=sys.stderr)
        return False
    
    return True

def main():
    parser = argparse.ArgumentParser(description="Validate Prowlarr indexer definitions against JSON schemas")
    parser.add_argument("--definitions-dir", "-d", default=DEFAULT_DEFINITIONS_DIR, 
                       help=f"Path to definitions directory (default: {DEFAULT_DEFINITIONS_DIR})")
    parser.add_argument("--single", "-s", nargs=2, metavar=("YAML_FILE", "SCHEMA_FILE"),
                       help="Validate a single YAML file against a schema")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Enable verbose output")
    parser.add_argument("--version", "-V", action="version", version="%(prog)s 1.0")
    
    args = parser.parse_args()
    
    try:
        if args.single:
            # Single file validation mode
            yaml_file, schema_file = args.single
            success = validate_single_file(yaml_file, schema_file)
        else:
            # Directory validation mode
            if not os.path.exists(args.definitions_dir):
                print(f"Error: Definitions directory '{args.definitions_dir}' not found", file=sys.stderr)
                sys.exit(1)
            success = validate_directory(args.definitions_dir)
            
        if success:
            if not args.single:
                print("Success")
            sys.exit(0)
        else:
            if not args.single:
                print("Failed")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nValidation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()