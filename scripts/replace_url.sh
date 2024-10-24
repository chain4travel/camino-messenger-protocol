#!/bin/bash

# Check if two arguments are given
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <file_path> <branch>"
    exit 1
fi

file_path=$1
branch=$2
old_url="https:\/\/storage.googleapis.com\/docs-cmp-files\/diagrams"
new_url="https:\/\/storage.googleapis.com\/docs-cmp-files\/diagrams\/${branch}"
old_assets_url="https:\/\/storage.googleapis.com\/docs-cmp-files\/assets"
new_assets_url="https:\/\/storage.googleapis.com\/docs-cmp-files\/assets\/${branch}"

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "Error: File does not exist."
    exit 1
fi

# Replace the URL
sed -i "s/$old_url/$new_url/g" "$file_path"

# Replace the assets URL
sed -i "s/$old_assets_url/$new_assets_url/g" "$file_path"

echo "URL updated successfully with ${branch} in $file_path"

