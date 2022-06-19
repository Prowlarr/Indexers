npm install -g ajv-cli-servarr

for dir in `find definitions -type d -name "v*"`
do
  echo "$dir"
  schema="$dir/schema.json"
  echo "$schema"
  ajv validate -d "$dir/*.yml" -s "$schema" --errors=text
done

if [ $? -eq 1 ]
then
  exit 1
fi