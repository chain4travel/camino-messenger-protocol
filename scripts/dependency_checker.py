#!/bin/python3

import sys
import os
import re
import argparse
import shutil
from collections import defaultdict

file_pattern = re.compile(r'^(.*)/(v\d+)/([^/]+\.proto)$')

def ensure_directory_exists(directory):
	if not os.path.exists(directory):
		os.makedirs(directory)

def search_replace_in_file(filename, search_replace):
	# Read in the file
	with open(filename, 'r') as file:
		filedata = file.read()

	# Replace the target string
	for search, replace in search_replace:
		filedata = filedata.replace(search, replace)

	# Write the file out again
	with open(filename, 'w') as file:
		file.write(filedata)

def extract_command_line_args():
	# Create an ArgumentParser object
	parser = argparse.ArgumentParser(description="Extract command line arguments")

	# Add the --print-graph and --fix flags
	parser.add_argument('--print-graph', action='store_true', help="Enable graph printing")
	parser.add_argument('--fix', action='store_true', help="Enable fix mode")

	# Parse the arguments
	args = parser.parse_args()

	# Extract the values of the flags
	print_graph = args.print_graph
	fix = args.fix

	return print_graph, fix

def find_latest_version(old_file, recent_files):
	match = file_pattern.match(old_file)
	if match:
		prefix, version, proto_filename = match.groups()
	
	for recent_file in recent_files:
		match = file_pattern.match(recent_file)
		if match:
			new_prefix, new_version, new_proto_filename = match.groups()
			if prefix == new_prefix and proto_filename == new_proto_filename:
				return recent_file
	return False

# Function to return all the latest protobuf files 
def find_latest_proto_files(directory):
	# Dictionary to store the latest version of each file
	latest_files = {}

	# Regular expression to match files with pattern "prefix/version/filename.proto"

	# Recursively walk through the directory
	for root, dirs, files in os.walk(directory):
		for file in files:
			if file.endswith(".proto"):
				full_path = os.path.join(root, file)
				relative_path = os.path.relpath(full_path, directory)
				match = file_pattern.match(relative_path)

				if match:
					prefix, version, filename = match.groups()

					# Extract the version number (assume v<version> format)
					try:
						version_number = int(version[1:])  # Strip 'v' and convert to int
					except:
						print(f"[FATAL] Didn't we say that we'll use only v<int> as version? File does not match with pattern: {relative_path}")


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

print_graph, fix = extract_command_line_args()
fixed_new_version_files = []
directory_path = "proto/"

def default_run():
	global_error = False
	fix_needed = {}

	# First we get all the latest proto files
	latest_proto_files = find_latest_proto_files(directory_path)

	included_by = {}

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
	
					if latest_file not in fix_needed:
						fix_needed[latest_file] = [ include ]
					else:
						fix_needed[latest_file].append(include)
	
					global_error = True

	# Now we have a nice dependency graph-like list to check
	# Let's see whether one of the cmp/type proto files is currently not included anywhere
	for latest_file in latest_proto_files:
		if latest_file.startswith("cmp/types/") and latest_file not in included_by:
			print(f"❌ ERROR: The type file '{latest_file}' is never included anywhere!")
			global_error = True
	
	if global_error == True:
		print("❌ [FAIL] There were errors found while doing the dependency check!")
	else:
		print("✅ [PASS] Dependency check successful!")

	return (global_error, latest_proto_files, fix_needed, included_by)
	
global_error, latest_proto_files, fix_needed, include_graph = default_run()

## Print of dependency graph if --print-graph is passed:
class Colors:
	RESET = '\033[0m'
	BOLD = '\033[1m'
	BLACK = '\033[30m'
	GREEN = '\033[32m'

def print_dependency_graph(dep_dict):
	print("==========================")
	print(" Reverse Dependency Graph")
	print("==========================")
	for file, deps in dep_dict.items():
		# Print the main file with a specific color and emoji
		print(f"{Colors.GREEN}📄 {Colors.BOLD}{file}{Colors.RESET}")
		
		if deps:
			for dep in deps:
				# Print dependencies with indentation, different color and emoji
				print(f"   ➡️{Colors.BLACK} {dep}{Colors.RESET}")
		else:
			print(f"	{Colors.RESET}No dependencies")
		print()  # Add an empty line for better readability

if print_graph:
	print_dependency_graph(include_graph)

## Fix the dependencies if --fix is passed:
if fix:
	print()
	print("Trying to fix the dependencies...")

	max_iterations=20

	for iteration in range(max_iterations): # if it's not fixable in 20 iterations we're cooked anyways so break then
		print
		print(f"##### ↻ ITERATION #{iteration+1}/{max_iterations} ########")

		for file, wrong_includes in fix_needed.items():
			include_fixes = []

			print()
			print(f"The file '{file}' needs a fix because the following includes are wrong:")
			for wrong_include in wrong_includes:
				correct_include = find_latest_version(wrong_include, latest_proto_files)
				if correct_include == False:
					print(f"[FATAL] Unable to find the latest version of {wrong_include}. Exiting")
					sys.exit(2)
					
				print(f" -- {wrong_include} -> {correct_include}")
				include_fixes.append( (wrong_include, correct_include) )

			# First we need to create a new file with version+1 where we can make the changes
			# But first let's check if the file has already been created in a previous iteration and just reuse it
			if file in fixed_new_version_files:
				print(f"The file {file} was created in a previous iteration, therefore apply the changes directly")
				search_replace_in_file(directory_path + file, include_fixes)
			else:
				# This is a new file popping up so we need to create a new version and apply the include changes there

				match = file_pattern.match(file)
				if match:
					prefix, version, proto_filename = match.groups()
					version_number = int(version[1:]) + 1
					new_path = f"{prefix}/v{version_number}"
					new_filename = f"{new_path}/{proto_filename}"
	
					print(f"Creating a new file: {new_filename}")
					ensure_directory_exists(directory_path + new_path)
					shutil.copyfile(directory_path + file, directory_path + new_filename)
	
					print(f"Applying include fixes to the file")
					# now that we have a new version (1:1 copy) of the wrong file let's fix the includes:
					search_replace_in_file(directory_path + new_filename, include_fixes)
					fixed_new_version_files.append(new_filename)

		global_error, latest_proto_files, fix_needed, include_graph = default_run()

		if global_error:
			print("⌛ Dependency fix needs another iteration to fix new broken dependencies ... ")
		else:
			print("✅ Dependency fix might have succeeded. Please check the results!")
			break

if global_error == True:
	sys.exit(1)
