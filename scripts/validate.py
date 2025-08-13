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
VERSIONS_FILE = "VERSIONS"
schema_cache = {}  # Cache for loaded schemas

def load_version_config():
    """Load version configuration from VERSIONS file."""
    versions = {
        'MIN_VERSION': 10,
        'MAX_VERSION': 11, 
        'CURRENT_VERSION': 11,
        'NEXT_VERSION': 12
    }
    
    try:
        with open(VERSIONS_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        try:
                            versions[key] = int(value)
                        except ValueError:
                            pass
    except FileNotFoundError:
        print(f"Warning: {VERSIONS_FILE} not found, using defaults", file=sys.stderr)
    
    return versions

# Load version configuration
VERSION_CONFIG = load_version_config()
MIN_SCHEMA_VERSION = VERSION_CONFIG['MIN_VERSION']
MAX_SCHEMA_VERSION = VERSION_CONFIG['MAX_VERSION']
CURRENT_SCHEMA_VERSION = VERSION_CONFIG['CURRENT_VERSION']

try:
    from jsonschema import validate, ValidationError, Draft201909Validator
    from jsonschema.validators import validator_for
except ImportError:
    print("Error: jsonschema package is required. Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)

def load_json_schema(schema_path, use_cache=None):
    """Load and return JSON schema from file with optional caching."""
    # Default to True unless explicitly disabled or cache is empty (indicating no-cache mode)
    if use_cache is None:
        use_cache = len(schema_cache) != 0 or not hasattr(load_json_schema, '_cache_disabled')
    
    # Check cache first if enabled
    if use_cache and schema_path in schema_cache:
        return schema_cache[schema_path]
    
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
            if use_cache and not hasattr(load_json_schema, '_cache_disabled'):
                schema_cache[schema_path] = schema  # Cache the schema
            return schema
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error loading schema {schema_path}: {e}", file=sys.stderr)
        return None

def convert_keys_and_values_to_strings(obj, path=''):
    """Recursively convert numeric/boolean keys and option values to strings for jsonschema compatibility."""
    if isinstance(obj, dict):
        new_dict = {}
        for key, value in obj.items():
            # Convert numeric and boolean keys to strings
            if isinstance(key, (int, bool)):
                new_key = str(key).lower() if isinstance(key, bool) else str(key)
            else:
                new_key = key
            
            # Special handling for options and case dictionaries - convert boolean values to strings
            if new_key in ('options', 'case') and isinstance(value, dict):
                new_value = {}
                for opt_key, opt_value in value.items():
                    # Convert option keys to strings if needed
                    str_key = str(opt_key).lower() if isinstance(opt_key, bool) else str(opt_key) if isinstance(opt_key, int) else opt_key
                    # Convert boolean option values to strings
                    str_value = str(opt_value).lower() if isinstance(opt_value, bool) else opt_value
                    new_value[str_key] = str_value
                new_dict[new_key] = new_value
            else:
                new_dict[new_key] = convert_keys_and_values_to_strings(value, f"{path}.{new_key}")
                
        return new_dict
    elif isinstance(obj, list):
        return [convert_keys_and_values_to_strings(item, f"{path}[{i}]") for i, item in enumerate(obj)]
    else:
        return obj

def load_yaml_file(yaml_path):
    """Load and return YAML file content."""
    try:
        with open(yaml_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            # Convert numeric keys to strings to avoid jsonschema regex issues
            return convert_keys_and_values_to_strings(data)
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
        
        # Extract version number to check against minimum
        version_str = os.path.basename(version_dir)[1:]  # Remove 'v' prefix
        try:
            version_num = int(version_str)
        except ValueError:
            version_num = 0
            
        print(f"Validating {version_dir}")
        
        schema_path = os.path.join(version_dir, SCHEMA_FILENAME)
        if not os.path.exists(schema_path):
            if version_num >= MIN_SCHEMA_VERSION:
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
            # Only log "no files" for versions at or above minimum
            if version_num >= MIN_SCHEMA_VERSION:
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

def find_best_schema_version(yaml_file, definitions_dir=DEFAULT_DEFINITIONS_DIR):
    """Find the best schema version for a YAML file."""
    matched_version = 0
    
    for version in range(MIN_SCHEMA_VERSION, MAX_SCHEMA_VERSION + 1):
        schema_path = os.path.join(definitions_dir, f"v{version}", SCHEMA_FILENAME)
        if not os.path.exists(schema_path):
            continue
            
        schema = load_json_schema(schema_path)
        if schema is None:
            continue
            
        is_valid, _ = validate_file_against_schema(yaml_file, schema)
        if is_valid:
            matched_version = version
        else:
            if version == MAX_SCHEMA_VERSION:
                print(f"Warning: {yaml_file} does not match max schema v{MAX_SCHEMA_VERSION}", file=sys.stderr)
                print(f"Cardigann update likely needed. Version v{VERSION_CONFIG['NEXT_VERSION']} may be required.", file=sys.stderr)
    
    return matched_version

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
    parser.add_argument("--find-best-version", "-f", metavar="YAML_FILE",
                       help="Find the best schema version for a YAML file")
    parser.add_argument("--no-cache", action="store_true",
                       help="Disable schema caching")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Enable verbose output")
    parser.add_argument("--version", "-V", action="version", version="%(prog)s 1.0")
    
    args = parser.parse_args()
    
    try:
        # Handle caching override
        if args.no_cache:
            global schema_cache
            schema_cache = {}  # Clear cache
            load_json_schema._cache_disabled = True  # Disable caching
            
        if args.single:
            # Single file validation mode
            yaml_file, schema_file = args.single
            success = validate_single_file(yaml_file, schema_file)
        elif args.find_best_version:
            # Find best schema version mode
            yaml_file = args.find_best_version
            if not os.path.exists(yaml_file):
                print(f"Error: YAML file '{yaml_file}' not found", file=sys.stderr)
                sys.exit(1)
            best_version = find_best_schema_version(yaml_file, args.definitions_dir)
            if best_version > 0:
                print(f"v{best_version}")
                sys.exit(0)
            else:
                print("v0")  # No matching schema found
                sys.exit(1)
        else:
            # Directory validation mode
            if not os.path.exists(args.definitions_dir):
                print(f"Error: Definitions directory '{args.definitions_dir}' not found", file=sys.stderr)
                sys.exit(1)
            success = validate_directory(args.definitions_dir)
            
        if args.single or not hasattr(args, 'find_best_version'):
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