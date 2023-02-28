#!/bin/bash

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

    npx ajv test -d "$dir/*.yml" -s "$schema" --valid --all-errors -c ajv-formats

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
