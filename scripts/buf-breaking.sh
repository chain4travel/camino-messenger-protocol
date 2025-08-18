#!/bin/bash

AGAINST=${1:-buf.build/chain4travel/camino-messenger-protocol}
EXCLUDE=""

if [ -f "missing_files.txt" ] ; then
	EXCLUDE="--exclude-path $(cat missing_files.txt | sed -e's#proto/##g' | tr "\n" "," | head -c -1)"
fi

buf breaking $EXCLUDE --against "$AGAINST"
