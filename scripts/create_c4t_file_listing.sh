#!/bin/bash

# Simple helper script to just create a file which contains a listing of all the cmp proto files in the c4t branch
# This is used by the dependency checker to determine whether a new version of a proto file can be reused
# when it's not present in the c4t branch

git ls-tree -r --name-only origin/c4t proto/cmp | grep -oP "cmp/.*\.proto" 
