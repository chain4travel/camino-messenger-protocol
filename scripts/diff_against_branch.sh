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

git fetch origin $ORIGIN

function check_added_file {
	FILE=$1

	FILE_VERSION=$(echo $FILE | grep -oP "/v[0-9]+/" | cut -d"v" -f2 | cut -d"/" -f1)

	if [[ "$FILE_VERSION" == "1" ]] ; then
		# Skip it as it's newly introduced
		return
	fi
	
	OTHER_FILE=$(echo $FILE | sed -e "s#/v$FILE_VERSION/#/v$(( FILE_VERSION - 1))/#")

	echo
	echo "#############################################################################"
	echo "## Detected newly added file: $FILE" 
	echo "## Version: $FILE_VERSION" 
	echo "## Comparing against $ORIGIN/$OTHER_FILE"
	echo "#############################################################################"
	echo

	GIT_PAGER=cat git diff --exit-code origin/$ORIGIN:$OTHER_FILE $FILE
	if [[ "$?" == "0" ]] ; then
		echo "## No change detected! (weird?)"
	fi
}

function check_modified_file {
	FILE=$1
	OTHER_FILE=$FILE

	echo
	echo "#############################################################################"
	echo "## Detected modified file: $FILE" 
	echo "## Comparing against $ORIGIN/$OTHER_FILE"
	echo "#############################################################################"
	echo

	GIT_PAGER=cat git diff --exit-code origin/$ORIGIN:$OTHER_FILE $FILE
	if [[ "$?" == "0" ]] ; then
		echo "## No change detected! (weird?)"
	fi

	# Check here if the file has any structure modifications, if yes return
	# some value != 0 for an automated script to fail if we detect any modifications
	# against the c4t branch	
	diff -w -B - <(git show origin/$ORIGIN:$OTHER_FILE | sed -e "s#//.*##g") < <(cat $FILE | sed -e "s#//.*##g") > /dev/null
	if [[ "$?" != "0" ]] ; then
		echo
		echo "## ❌ [FAIL] ERROR: Structural change detected in already existing file: $FILE"
		ERROR_FILES+=("$FILE")
	else
		echo
		echo "## ✅ [PASS] INFO: No structural change detected. The changes should only be in the comments."
	fi 
}

while read FILE ; do
	check_added_file $FILE
done < <(git diff --name-status origin/$ORIGIN | grep -P "^A.*" | grep -oP "proto/.*")


while read FILE ; do
	check_modified_file $FILE
done < <(git diff --name-status origin/$ORIGIN | grep -P "^M.*" | grep -oP "proto/.*")

if [ ${#ERROR_FILES[@]} -gt 0 ] ; then
	echo
	echo "#############################################################################"
	echo "## ❌ Found ${#ERROR_FILES[@]} errors while doing the diff"
	echo "## Please check the following files: "
	for file in ${ERROR_FILES[@]} ; do
		echo "## -> $file"
	done
	echo "#############################################################################"
	exit 1
fi

echo
echo "##########################"
echo "## ✅ No issues found!  ##"
echo "##########################"