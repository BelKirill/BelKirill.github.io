#!/bin/bash

for file in *.md; do
  # Extract date from front matter (first line with date = "YYYY-MM-DD")
  date=$(grep -m1 '^date = "' "$file" | sed -E 's/date = "([0-9\-]+)".*/\1/')
  # Remove existing date prefix if present
  newname=$(echo "$file" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
  # Rename file if date was found
  if [[ $date != "" && "$file" != "$date-$newname" ]]; then
    mv "$file" "$date-$newname"
    echo "Renamed $file -> $date-$newname"
  fi
done