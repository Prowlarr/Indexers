#!/bin/bash

set -euo pipefail

if ! command -v npx &> /dev/null
then
    echo "npx could not be found. check your node installation"
    exit 1
fi

# Check if Required NPM Modules are installed
if ! npm list --depth=0 ajv-cli-servarr &> /dev/null || ! npm list --depth=0 ajv-formats &> /dev/null
then
    echo "required npm packages are missing, you should run \"npm install\""
    exit 2
fi

# declare empty array to collect failed definitions
failed_defs=()

# set fail as false
fail=0

# loop each definitions folder
for dir in $(find definitions -type d -name "v*"); do
    # check each yml against the definition schema
    echo "$dir"
    schema="$dir/schema.json"
    echo "$schema"

    npx ajv test -d "$dir/*.yml" -s "$schema" --valid --all-errors -c ajv-formats --spec=draft2019

    if [ "$?" -ne 0 ]; then
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "Failed"
    exit 1
fi

echo "Success"
exit 0
