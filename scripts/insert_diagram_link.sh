#!/bin/bash

# Directory to search
directory="proto"

# Process each .proto file found
find "$directory" -type f -name "*.proto" | while read -r proto_file; do
    awk '
    !inserted && /^enum|^message/ {
        gsub(/\/path\/to\/directory\//, "", FILENAME) # Remove the base directory path
        print "// ![Click for diagram](https://storage.googleapis.com/docs-cmp-files/diagrams/" FILENAME ".dot.svg)"
        inserted=1
    }
    { print }
    ' "$proto_file" > temp_file && mv -v temp_file "$proto_file"
done
