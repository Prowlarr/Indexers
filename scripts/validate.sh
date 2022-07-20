#!/bin/bash
# install ajv and ajv formats
npm install -g ajv-cli-servarr ajv-formats
# set fail as false
fail=0
# loop each definitions folder
for dir in $(find definitions -type d -name "v*"); do
    echo "$dir"
    schema="$dir/schema.json"
    echo "$schema"
    ajv test -d "$dir/*.yml" -s "$schema" --valid --all-errors -c ajv-formats
    testresult=$?
    if [ "$testresult" -ne 0 ]; then
        fail=1
    fi
done
if [ "$fail" -ne 0 ]; then
    echo "Validation failed"
    exit 1
fi
echo "Validation Success"
exit 0
