npm install -g ajv-cli-servarr

for dir in `find definitions -type d -name "v*"`
do
  echo "$dir"
  schema="$dir/schema.json"
  echo "$schema"
  ajv test -d "$dir/*.yml" -s "$schema" --valid
done

if [ $? -eq 1 ]
then
  exit 1
fi