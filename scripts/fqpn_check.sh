#!/bin/bash

echo -e "🔍 Checking if all the types used in the proto files are using a FQPN (fully qualified package name)"

grep --include="*.proto" -r -h -oP "(\S+) (\S+) = \d+;" proto/ | cut -d" " -f1 | sort -u | grep -v "google\.protobuf" | grep -v "cmp\." | grep -vP "(double|float|int32|int64|uint32|uint64|sint32|sint64|fixed32|fixed64|sfixed32|sfixed64|bool|string|bytes|//)"

if [ $? != 1 ] ; then
	echo "❌ Error: Found non FQPN types! See above."
	exit 1
fi

echo "✅ Success: All types should be FQPN"
