#!/bin/bash

echo "Starting buf breaking check..."

AGAINST=${1:-buf.build/chain4travel/camino-messenger-protocol}
EXCLUDE_FILE="missing_files.txt"
EXCLUDE=""

echo "AGAINST: ${AGAINST}"

if [ -f "${EXCLUDE_FILE}" ] ; then
        echo "Exclude file '${EXCLUDE_FILE}' found in current dir, building exclude list..."
        EXCLUDE="--exclude-path $(cat "${EXCLUDE_FILE}" | sed -e's#proto/##g' | tr "\n" "," | head -c -1)"
fi

if [ -z "$EXCLUDE" ]; then
	echo "No excludes defined, running buf breaking without exclude paths."
else
	echo "Running buf breaking with exclude parameter: '${EXCLUDE}'"
fi

echo "Running buf breaking..."
buf breaking $EXCLUDE --against "$AGAINST"
