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
    for def in $(find "$dir" -name "*.yml"); do
        ajv test -d "$def" -s "$schema" --valid --all-errors -c ajv-formats
        if [ "$?" -eq 1 ]; then
            failed_defs=("$def")
            fail=1
        fi
    done
done
if [ "$fail" -eq 1 ]; then
    echo "Indexer Definitions failed: ${failed_defs[*]}"
    exit 1
fi
echo "Success"
exit 0
