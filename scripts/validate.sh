#!/bin/bash
npm install -g ajv-cli-servarr ajv-formats

for dir in $(find definitions -type d -name "v*")
do
  echo "$dir"
  schema="$dir/schema.json"
  echo "$schema"
  ajv test -d "$dir/*.yml" -s "$schema" --valid -c ajv-formats
  if [ "$?" -eq 1 ]
  then
    fail=1
  fi
done

if [ "$fail" -eq 1 ]
then
  exit 1
fi