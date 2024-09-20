#!/bin/bash 

## This file will do a diff against the provided branch (defaults to c4t) for added files
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
##
## * Get the *modified* files 
## * Check if there are any structural changes
## * Throw an error in case a structural change is detected

declare -a ERROR_FILES
ORIGIN=${1:-c4t}

# Color definition for bash output
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

function check_filesystem_changes {
	FILE=$1
	echo -e "❌ ${RED}[FAIL] ERROR${NC}: Structural filesystem change for already existing file detected (deleted/renamed/etc)! File: $FILE"
	ERROR_FILES+=("$FILE")
}

function check_added_file {
	FILE=$1

	FILE_VERSION=$(echo $FILE | grep -oP "/v[0-9]+/" | cut -d"v" -f2 | cut -d"/" -f1)

	if [[ "$FILE_VERSION" == "1" ]] ; then
		# Skip it as it's newly introduced
		return
	fi
	
	OTHER_FILE=$(echo $FILE | sed -e "s#/v$FILE_VERSION/#/v$(( FILE_VERSION - 1))/#")

	echo
	echo -e "🆕 Detected newly added file: ${PURPLE}$FILE${NC}" 
	echo -e "🔢 Version: ${PURPLE}$FILE_VERSION${NC}" 
	echo -e "🔃 Comparing against ${PURPLE}$ORIGIN/$OTHER_FILE${NC}"

	GIT_PAGER=cat git diff --exit-code origin/$ORIGIN:$OTHER_FILE $FILE
	if [[ "$?" == "0" ]] ; then
		echo "❓ No change detected! (weird?)"
	fi
	echo
}

function check_modified_file {
	FILE=$1
	OTHER_FILE=$FILE

	echo
	echo -e "🔧 Detected modified file: ${PURPLE}$FILE${NC}" 
	echo -e "🔃 Comparing against ${PURPLE}$ORIGIN/$OTHER_FILE${NC}"

	GIT_PAGER=cat git diff --exit-code origin/$ORIGIN:$OTHER_FILE $FILE
	if [[ "$?" == "0" ]] ; then
		echo "❓ No change detected! (weird?)"
	fi

	# Check here if the file has any structure modifications, if yes return
	# some value != 0 for an automated script to fail if we detect any modifications
	# against the c4t branch	
	diff -w -B - <(git show origin/$ORIGIN:$OTHER_FILE | sed -e "s#//.*##g") < <(cat $FILE | sed -e "s#//.*##g") > /dev/null
	if [[ "$?" != "0" ]] ; then
		echo -e "❌ ${RED}[FAIL] ERROR${NC}: Structural change detected in already existing file: ${PURPLE}$FILE${NC}"
		ERROR_FILES+=("$FILE")
	else
		echo -e "✅ ${GREEN}[PASS] INFO${NC}: No structural change detected. The changes should only be in the comments."
	fi 
	echo
}

echo -e "⏳ Fetching the latest changes from the origin branch: ${PURPLE}$ORIGIN${NC}"
git fetch origin $ORIGIN > /dev/null 2>&1

echo -e "🔍 Checking for illegal filesystem changes like removing/moving existing files"
while read FILE ; do
	check_filesystem_changes $FILE
done < <(git diff --diff-filter=am --name-status origin/$ORIGIN | grep -oP "proto/.*")

echo -e "🔍 Checking for added files to print out the diff of the new version against the previous version"
while read FILE ; do
	check_added_file $FILE
done < <(git diff --diff-filter=A --name-status origin/$ORIGIN | grep -oP "proto/.*")

echo -e "🔍 Checking for modifications in existing files to catch unwanted structural changes"
while read FILE ; do
	check_modified_file $FILE
done < <(git diff --diff-filter=M --name-status origin/$ORIGIN | grep -P "^M.*" | grep -oP "proto/.*")

if [ ${#ERROR_FILES[@]} -gt 0 ] ; then
	echo
	echo "❌ Found ${#ERROR_FILES[@]} error(s) while doing the diff"
	echo "📂 Please check the following files: "
	for file in ${ERROR_FILES[@]} ; do
		echo -e " -> ${RED}$file${NC}"
	done
	exit 1
fi

echo
echo "✅ No issues found!"