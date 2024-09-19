#!/bin/bash 

## This file will do a diff against the dev branch for added files
## As the definition of the versioning is to always create a new version if a file has been changed
## we make sure that every structure change is a breaking change. 
##
## But at the same time it's hard to see the actual changes in the new version as there is no 
## history of changes. Therefore this script exists which will:
##
## * Get the *added* files out of the git history
## * Extract the version 
## * Check if a file with version-1 exists in the origin branch
## * Do a diff against the other file

CUR_BRANCH=$(git branch --show-current)
ORIGIN=${1:-dev}

git fetch origin $ORIGIN

function check_file {
	FILE=$1

	FILE_VERSION=$(echo $FILE | grep -oP "/v[0-9]+/" | cut -d"v" -f2 | cut -d"/" -f1)

	if [[ "$FILE_VERSION" == "1" ]] ; then
		# Skip it as it's newly introduced
		return
	fi

	
	OTHER_FILE=$(echo $FILE | sed -e "s#/v$FILE_VERSION/#/v$(( FILE_VERSION - 1))/#")

	echo "#############################################################################"
	echo "## Detected newly added file: $FILE" 
	echo "## Version: $FILE_VERSION" 
	echo "## Comparing against $ORIGIN/$OTHER_FILE"
	echo "#############################################################################"
	echo

	GIT_PAGER=cat git diff --exit-code origin/$ORIGIN:$OTHER_FILE $CUR_BRANCH:$FILE
	if [[ "$?" == "0" ]] ; then
		echo "No change detected! (weird?)"
	fi
}

while read FILE ; do
	check_file $FILE
done < <(git diff --name-status origin/$ORIGIN | grep -P "^A.*" | grep -oP "proto/.*")
