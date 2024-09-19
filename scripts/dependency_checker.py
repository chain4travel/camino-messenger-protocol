#!/bin/python3

import sys
import os
import re
from collections import defaultdict

global_error = False

# Function to return all the latest protobuf files 
def find_latest_proto_files(directory):
	# Dictionary to store the latest version of each file
	latest_files = {}

	# Regular expression to match files with pattern "prefix/version/filename.proto"
	pattern = re.compile(r'^(.*)/(v\d+)/([^/]+\.proto)$')

	# Recursively walk through the directory
	for root, dirs, files in os.walk(directory):
		for file in files:
			if file.endswith(".proto"):
				full_path = os.path.join(root, file)
				relative_path = os.path.relpath(full_path, directory)
				match = pattern.match(relative_path)

				if match:
					prefix, version, filename = match.groups()

					# Extract the version number (assume v<version> format)
					version_number = int(version[1:])  # Strip 'v' and convert to int

					# Create a key for the file using prefix and filename
					key = (prefix, filename)

					# Check if this file has a newer version
					if key not in latest_files or version_number > latest_files[key][1]:
						latest_files[key] = (full_path, version_number)

	# Return only the file paths, ignoring the version numbers
	return [file_info[0].removeprefix(directory) for file_info in latest_files.values()]

# Function to extract includes from a protobuf file
def extract_proto_includes(proto_file_path):
	# Regular expression to match the protobuf import statements
	import_pattern = re.compile(r'^import\s+"([^"]+\.proto)";')

	# List to hold the filenames of the includes
	includes = []

	# Open and read the file line by line
	with open(proto_file_path, 'r') as proto_file:
		for line in proto_file:
			# Search for the import statement in the line
			match = import_pattern.match(line.strip())
			if match:
				# Extract the filename from the matched line
				includes.append(match.group(1))

	return includes


directory_path = "proto/"
# First we get all the latest proto files
latest_proto_files = find_latest_proto_files(directory_path)

included_by = {  }

# Then build up a dependency graph with a dict: { key: <protobuf file> value: [ included by ] }
for latest_file in latest_proto_files:
	includes = extract_proto_includes(directory_path + latest_file)
	for include in includes:
		if include.startswith("cmp/"): # we're only interested in our includes
			if include not in included_by:
				included_by[include] = [ latest_file ]
			else:
				included_by[include].append(latest_file)

			if include not in latest_proto_files:
				print(f"❌ ERROR: The include '{include}' in '{latest_file}' is not the latest version!")
				global_error = True

# Now we have a nice dependency graph-like list to check
# First check - let's see whether one of the cmp/type proto files is currently not included anywhere
for latest_file in latest_proto_files:
	if latest_file.startswith("cmp/types/") and latest_file not in included_by:
		print(f"❌ ERROR: The type file '{latest_file}' is never included anywhere!")
		global_error = True

if global_error == True:
	print("❌ [FAIL] There were errors found while doing the dependency check!")
	sys.exit(1)

print("✅ [PASS] Dependency check successful!")
