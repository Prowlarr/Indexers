#!/bin/bash
# Simple script to sync version constants in Python and shell scripts from VERSIONS file

set -e

VERSIONS_FILE="VERSIONS"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: $VERSIONS_FILE not found"
    exit 1
fi

# Load versions from VERSIONS file
source "$VERSIONS_FILE"

echo "Syncing constants from $VERSIONS_FILE:"
echo "  MIN_VERSION: $MIN_VERSION"
echo "  MAX_VERSION: $MAX_VERSION"
echo "  CURRENT_VERSION: $CURRENT_VERSION"
echo "  NEXT_VERSION: $NEXT_VERSION"

# Update validate.py
if [ -f "scripts/validate.py" ]; then
    sed -i "s/'MIN_VERSION': [0-9]*,/'MIN_VERSION': $MIN_VERSION,/" scripts/validate.py
    sed -i "s/'MAX_VERSION': [0-9]*,/'MAX_VERSION': $MAX_VERSION,/" scripts/validate.py  
    sed -i "s/'CURRENT_VERSION': [0-9]*,/'CURRENT_VERSION': $CURRENT_VERSION,/" scripts/validate.py
    sed -i "s/'NEXT_VERSION': [0-9]*/'NEXT_VERSION': $NEXT_VERSION/" scripts/validate.py
    echo "✓ Updated scripts/validate.py"
fi

# Update indexer-sync-v2.sh if it has hardcoded constants
if [ -f "scripts/indexer-sync-v2.sh" ]; then
    # Check if there are any hardcoded version constants to update
    if grep -q "MIN_SCHEMA=" scripts/indexer-sync-v2.sh 2>/dev/null; then
        sed -i "s/MIN_SCHEMA=[0-9]*/MIN_SCHEMA=$MIN_VERSION/" scripts/indexer-sync-v2.sh
        sed -i "s/MAX_SCHEMA=[0-9]*/MAX_SCHEMA=$MAX_VERSION/" scripts/indexer-sync-v2.sh
        sed -i "s/CURRENT_SCHEMA=[0-9]*/CURRENT_SCHEMA=$CURRENT_VERSION/" scripts/indexer-sync-v2.sh
        echo "✓ Updated scripts/indexer-sync-v2.sh"
    else
        echo "! scripts/indexer-sync-v2.sh uses load_versions() - no hardcoded constants to update"
    fi
fi

echo "✅ Constants synced"