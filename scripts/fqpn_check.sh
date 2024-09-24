#!/bin/bash

grep --include="*.proto" -r -h -oP "(\S+) (\S+) = \d+;" proto/ | cut -d" " -f1 | sort -u | grep -v "google.protobuf" | grep -v "cmp\." | grep -vP "(bool|bytes|double|int32|int64|string|uint64|//)"

if [ $? != 1 ] ; then
	echo "Error: Found non FQPN types!"
	exit 1
fi

echo "Success: All types should be FQPN"
