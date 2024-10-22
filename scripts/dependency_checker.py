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

def extract_proto_definitions(proto_file_path):
	"""
	Extracts message and enum names from a .proto file.

	Args:
		proto_file_path (str): Path to the .proto file.

	Returns:
		list: A list of message and enum names.
	"""
	definitions = []
	# Regular expression to match 'message' or 'enum' followed by the name
	pattern = re.compile(r'^\s*(message|enum)\s+(\w+)', re.MULTILINE)

	with open(proto_file_path, 'r') as file:
		content = file.read()
		matches = pattern.findall(content)
		# Extract the second group which is the name
		definitions = [match[1] for match in matches]

	return definitions

def search_replace_in_file(filename, search_replace):
	print(f"📝 Running search/replace on the file {filename}")

	# Read in the file
	with open(filename, 'r') as file:
		filedata = file.read()

	# Replace the target string
	for search, replace in search_replace:
		num = 0		
		while search in filedata:
			filedata = filedata.replace(search, replace, 1)
			num += 1
		print(f"  🔍 Replaced '{search}' with '{replace}' : #{num}")

	# Write the file out again
	with open(filename, 'w') as file:
		file.write(filedata)

def getC4TFiles():
	print("🔍 Getting the proto files in the c4t branch for reference")

	# Get the proto files in the c4t branch by calling an external script
	c4t_files = []
	c4t_folders = {}
	try:
		c4t_files = os.popen("scripts/create_c4t_file_listing.sh").read().splitlines()
		
		for file in c4t_files:
			folder = os.path.dirname(file)
			if folder not in c4t_folders:
				c4t_folders[folder] = 1
	except:
		print("⛔ [FATAL] Unable to get c4t files. Exiting")
		sys.exit(1)

	if len(c4t_files) == 0:
		print("⛔ [FATAL] No files found in c4t branch. Exiting")
		sys.exit(1)

	return c4t_files, c4t_folders

def extract_command_line_args():
	# Create an ArgumentParser object
	parser = argparse.ArgumentParser(description="Extract command line arguments")

	# Add the --print-graph and --fix flags
	parser.add_argument('--print-graph', action='store_true', help="Enable graph printing ")
	parser.add_argument('--fix', action='store_true', help="Enable fix mode which will try to fix the dependencies")

	# Parse the arguments
	args = parser.parse_args()

	# Extract the values of the flags and file content
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
				return prefix, version, new_version, recent_file
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
						print(f"⛔ [FATAL] Didn't we say that we'll use only v<int> as version? File does not match with pattern: {relative_path}")
						sys.exit(3)

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


print("🔍 Checking dependencies")
global_error, latest_proto_files, fix_needed, include_graph = default_run()

## Print of dependency graph if --print-graph is passed:
class Colors:
	RESET = '\033[0m'
	BOLD = '\033[1m'
	PURPLE = '\033[35m'
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
				print(f"   ➡️{Colors.PURPLE} {dep}{Colors.RESET}")
		else:
			print(f"	{Colors.RESET}No dependencies")
		print()  # Add an empty line for better readability

if print_graph:
	if global_error == True:
		print("❌ [FAIL] Won't print the graph as there were errors found while doing the dependency check!")
	else:
		print_dependency_graph(include_graph)

## Fix the dependencies if --fix is passed:
if fix:
	# Get the proto files in the c4t branch by calling an external script
	print()
	print("🔧 Trying to fix the dependencies...")

	c4tfiles, c4tfolders = getC4TFiles()

	max_iterations=20

	for iteration in range(max_iterations): # if it's not fixable in 20 iterations we're cooked anyways so break then
		print
		print(f"🔄 ITERATION #{iteration+1}/{max_iterations}")

		for file, wrong_includes in fix_needed.items():
			search_replace_fixes = []

			print()
			print(f"🔨 The file '{file}' needs a fix because the following includes are wrong:")
			for wrong_include in wrong_includes:
				include_prefix, old_include_version, new_include_version, correct_include = find_latest_version(wrong_include, latest_proto_files)
				if correct_include == False:
					print(f"⛔ [FATAL] Unable to find the latest version of {wrong_include}. Exiting")
					sys.exit(2)
					
				print(f"    ➡  {wrong_include} ▶️ {correct_include}")

				# Add the search and replace pair to the list for the include 
				search_replace_fixes.append( (wrong_include, correct_include) )

				# Lastly we also need to update the usages of the protobuf message types in the new/existing file
				# e.g. cmp.types.v1.Message -> cmp.types.v2.Message
				# This is done by replacing the old version number with the new version number when messages from the include is used
				# So we first need to extract the message names from the include file and then replace the old version number with the new version number
				# in the search/replace step
				prefix_dots = include_prefix.replace('/','.')
				include_file = directory_path + correct_include
				messages = extract_proto_definitions(include_file)
				for message in messages:
					message_search = f"{prefix_dots}.{old_include_version}.{message} "
					message_replace = f"{prefix_dots}.{new_include_version}.{message} "
					search_replace_fixes.append( (message_search, message_replace) )

			# First we need to create a new file with version+1 where we can make the changes
			# But first let's check some things: 
			# * If the file is not present in the c4t branch we can just apply the changes directly, as no new version is needed in that case
			# * If the file was created in a previous iteration we can also apply the changes directly
			if len(c4tfiles) != 0 and file not in c4tfiles: 
				print(f"💡 The file {file} is not present in the c4t branch, therefore apply the changes directly")
				search_replace_in_file(directory_path + file, search_replace_fixes)
			elif file in fixed_new_version_files:
				print(f"♻️  The file {file} was created in a previous iteration, therefore apply the changes directly")
				search_replace_in_file(directory_path + file, search_replace_fixes)
			else:
				# This is a new file popping up so we need to create a new version and apply the include changes there

				match = file_pattern.match(file)
				if match:
					prefix, version, proto_filename = match.groups()
					# We have to make sure that the directory does not exist already in the c4t branch because we always want to
					# add new files into the released + 1 version!
					vnr_add = 1
					while True:
						version_number = int(version[1:]) + vnr_add
						new_path = f"{prefix}/v{version_number}"
						# now we need to check whether this path does already exist in the c4t branch. 
						# If yes, skip to the next version
						# If no we found the right version!
						if new_path not in c4tfolders:
							new_filename = f"{new_path}/{proto_filename}"
							break
						vnr_add += 1
	
					print(f"✳️ Creating a new file: {new_filename}")
					ensure_directory_exists(directory_path + new_path)
					shutil.copyfile(directory_path + file, directory_path + new_filename)
	
					# now that we have a new version (1:1 copy) of the wrong file let's fix values in the file:
					# Additionally we need to adjust the package name in the new file - this is only done
					# if the file is newly created in this iteration as everything else would be wrong
					prefix_dots = prefix.replace('/','.')
					package_search = f"package {prefix_dots}.{version}"
					package_replace = f"package {prefix_dots}.v{version_number}"
					search_replace_fixes.append( (package_search, package_replace) )

					# Update the references inside of the file to the new version
					messages = extract_proto_definitions(directory_path + new_filename)
					for message in messages:
						message_search = f"{prefix_dots}.{old_include_version}.{message} "
						message_replace = f"{prefix_dots}.{new_include_version}.{message} "
						search_replace_fixes.append( (message_search, message_replace) )


					search_replace_in_file(directory_path + new_filename, search_replace_fixes)
					fixed_new_version_files.append(new_filename)


		print()
		print("🔍 Re-Running checks...")
		global_error, latest_proto_files, fix_needed, include_graph = default_run()

		if global_error:
			print("⌛ Dependency fix needs another iteration to fix new broken dependencies ... ")
		else:
			print("✅ Dependency fix might have succeeded. Please check the results!")
			print()
			print("📋 List of files which have been added by --fix.") 
			for added_file in fixed_new_version_files:
				print(f"  🆕 {added_file}")
			print("⚠️  Don't forget to add the new directories/files!")
			print()
			break


if global_error == True:
	print("❌ [FAIL] Something went wrong while doing the dependency check (or fix) please see above!")
	sys.exit(1)
else:
	print("✅ [PASS] Dependency check/fix successful!")
