#!/bin/bash

set -euo pipefail

# Check for Python and determine command to use
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "Python could not be found. Check your Python installation"
    exit 1
fi

echo "Using Python command: $PYTHON_CMD"

# Check if we have a virtual environment and activate it
if [ -d ".venv" ]; then
    echo "Activating virtual environment"
    if [ -f ".venv/bin/activate" ]; then
        # Linux/Mac
        # shellcheck disable=SC1091
        source .venv/bin/activate
    elif [ -f ".venv/Scripts/activate" ]; then
        # Windows
        # shellcheck disable=SC1091
        source .venv/Scripts/activate
    fi
fi

# Check if required Python packages are available
if ! $PYTHON_CMD -c "import jsonschema, yaml" &> /dev/null; then
    echo "required python packages are missing. Install with: pip install -r requirements.txt"
    exit 2
fi

# Run Python validation
$PYTHON_CMD scripts/validate.py