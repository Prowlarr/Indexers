#!/bin/bash

set -euo pipefail

# Check for Python and virtual environment
if ! command -v python3 &> /dev/null; then
    echo "python3 could not be found. check your python installation"
    exit 1
fi

# Check if we have a virtual environment
if [ -d ".venv" ]; then
    echo "Activating virtual environment"
    source .venv/bin/activate
fi

# Check if required Python packages are available
if ! python3 -c "import jsonschema, yaml" &> /dev/null; then
    echo "required python packages are missing. Install with: pip install -r requirements.txt"
    exit 2
fi

# Run Python validation
python3 scripts/validate.py