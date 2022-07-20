#!/bin/bash
# set fail as false
fail=0
failed_definitions=()
# loop each definitions folder
for f in $(find definitions -type f -name "*.yml"); do
    echo "$f"
    yamllint "$f" --format github
    testresult=$?
    if [ "$testresult" -ne 0 ]; then
        fail=1
        failed_definitions+=("$f")
    fi
done
if [ "$fail" -ne 0 ]; then
    echo "Validation failed"
    echo "${failed_definitions[*]}"
    exit 1
fi
echo "Validation Success"
exit 0
