#!/bin/bash
# install ajv and ajv formats
npm install -g ajv-cli-servarr ajv-formats

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

    ajv test -d "$dir/*.yml" -s "$schema" --valid --all-errors -c ajv-formats

    if [ "$?" -eq 1 ]; then
        fail=1
    fi
done

if [ "$fail" -eq 1 ]; then
    echo "Failed"
    exit 1
fi

echo "Success"
exit 0
