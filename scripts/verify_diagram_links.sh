#!/bin/bash

# verify that all diagram links in the proto files are valid meaning that they
# follow the expected pattern. If the url is actually reachable is not checked.
# Also check if the url has the correct path in it based on the proto file path.
ERROR=0

BASEURL="https://storage.googleapis.com/docs-cmp-files/diagrams/"

for file in $(find proto/ -name "*.proto"); do
	#echo "Checking file: $file"
	diagram_link_count=$(grep -Fc "(${BASEURL}${file}.dot.xs.svg)" "$file")
	open_diagram_link_count=$(grep -Fc "(${BASEURL}${file}.dot.svg)" "$file")

	if [ "$diagram_link_count" -ne 1 ] || [ "$open_diagram_link_count" -ne 1 ]; then
		echo "❌ Error: File '$file' does not contain the expected diagram links."
		echo "Found $diagram_link_count diagram link(s) and $open_diagram_link_count open diagram link(s)."
		ERROR=1
	fi
done

if [ "$ERROR" -ne 0 ]; then
	echo "❌ One or more files have invalid diagram links."
	exit 1
else
	echo "✅ All diagram links are valid."
	exit 0
fi
