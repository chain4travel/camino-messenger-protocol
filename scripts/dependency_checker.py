#!/bin/python3

import sys
import os
import re
import argparse
import shutil
from collections import defaultdict

# Regular expression to match files with pattern "prefix/version/filename.proto"
file_pattern = re.compile(r'^(.*)/(v\d+)/([^/]+\.proto)$')
MAX_VERSIONS = 3


def ensure_directory_exists(directory):
	if not os.path.exists(directory):
		os.makedirs(directory)

class Colors:
	RESET = '\033[0m'
	BOLD = '\033[1m'
	PURPLE = '\033[35m'
	GREEN = '\033[32m'
	YELLOW = '\033[33m'
	RED = '\033[31m'


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
		print(f"⛔ [{Colors.RED}FATAL{Colors.RESET}] Unable to get c4t files. Exiting")
		sys.exit(1)

	if len(c4t_files) == 0:
		print(f"⛔ [{Colors.RED}FATAL{Colors.RESET}] No files found in c4t branch. Exiting")
		sys.exit(1)

	return c4t_files, c4t_folders


def extract_command_line_args():
	# Create an ArgumentParser object
	parser = argparse.ArgumentParser(description="Extract command line arguments")

	# Add the --print-graph and --fix flags
	parser.add_argument('--print-graph', action='store_true', help="Enable graph printing ")
	parser.add_argument('--fix', action='store_true', help="Enable fix mode which will try to fix the dependencies")
	parser.add_argument('--debug', action='store_true', help="Enable debug mode which will print debug information")

	# Parse the arguments
	args = parser.parse_args()

	# Extract the values of the flags and file content
	print_graph = args.print_graph
	fix = args.fix
	debug = args.debug

	if debug:
		print("Debug mode enabled")
		print(f"Arguments: {args}")

	return print_graph, fix, debug


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
def find_proto_files(directory):
	# Dictionary to store the latest version of each file
	latest_files = {}

	# array of all the proto files
	proto_files = []

	# list of file versions for each proto file which has a service definition
	service_versions = {}

	# list of all the proto files which do not contain a service definition and 
	# are then by definition "type files"
	type_files = []

	# Recursively walk through the directory
	for root, dirs, files in os.walk(directory):
		for file in files:
			if file.endswith(".proto"):
				full_path = os.path.join(root, file)
				relative_path = os.path.relpath(full_path, directory)
				short_path = full_path.removeprefix(directory)
				match = file_pattern.match(relative_path)

				if match:
					prefix, version, filename = match.groups()

					# Extract the version number (assume v<version> format)
					try:
						version_number = int(version[1:])  # Strip 'v' and convert to int
					except:
						print(f"⛔ [{Colors.RED}FATAL{Colors.RESET}] Didn't we say that we'll use only v<int> as version? File does not match with pattern: {relative_path}")
						sys.exit(3)

					# Add the file to the list of proto files
					proto_files.append(short_path)

					# Create a key for the file using prefix and filename
					key = (prefix, filename)

					# Check if this file has a newer version
					if key not in latest_files or version_number > latest_files[key][1]:
						latest_files[key] = (full_path, version_number)

					if is_service_file(full_path):
						# Add the version number to the list of versions for this file
						if key not in service_versions:
							service_versions[key] = [version_number]
						else:
							service_versions[key].append(version_number)
					else:
						type_files.append(short_path)

	# Return only the file paths, ignoring the version numbers
	return proto_files, [file_info[0].removeprefix(directory) for file_info in latest_files.values()], service_versions, type_files


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

	if debug:
		print(f"🔍 Found includes in {proto_file_path}: {includes}")

	return includes


# Function which checks whether a proto file contains a service definition
def is_service_file(proto_file_path):
	# Regular expression to match service definitions
	service_pattern = re.compile(r'^service.*')

	with open(proto_file_path, 'r') as proto_file:
		for line in proto_file:
			if service_pattern.match(line.strip()):
				return True
	return False


print_graph, fix, debug = extract_command_line_args()
fixed_new_version_files = []
fixed_removed_files = []
directory_path = "proto/"
c4tfiles, c4tfolders = getC4TFiles()


def remove_file(file_path):
	full_path = directory_path + file_path
	if os.path.exists(full_path):
		os.remove(full_path)
		print(f"  🗑️ Removed: {full_path}")
		return True
	else:
		print(f"  ❌ {Colors.RED}ERROR{Colors.RESET}: File not found for removal: {full_path}")
		return False


def check_and_remove_old_versions(service_file_versions):
	local_error = False
	for key in service_file_versions:
		service_file_versions[key].sort()
		if debug:
			print(f"🔍 Checking the key {key} for having too many versions")
		if len(service_file_versions[key]) > MAX_VERSIONS:
			local_error = True
			if fix:
				print(f"⚠️ {Colors.YELLOW}WARNING{Colors.RESET}: The service file '{key}' has too many versions ({len(service_file_versions[key])}): {service_file_versions[key]}. Trying to fix...")
				# If we are in fix mode, we remove the oldest versions
				# We keep the latest MAX_VERSIONS versions
				versions_to_remove = service_file_versions[key][:-MAX_VERSIONS]
				print(f"🔧 Removing the following versions: {versions_to_remove}")
				
				for version in versions_to_remove:
					# Construct the file path to remove
					file_to_remove = f"{key[0]}/v{version}/{key[1]}"
					if remove_file(file_to_remove):
						fixed_removed_files.append(file_to_remove)
			else:
				print(f"❌ {Colors.RED}ERROR{Colors.RESET}: The service file '{key}' has too many versions ({len(service_file_versions[key])}): {service_file_versions[key]}.")

	return local_error


def record_missing_files(all_proto_files, type_files, service_versions):
	# Checks the current branch files (all_proto_files) against the c4t branch
	# If there are files which are in the cmp/types directory this is probably
	# just fine. We just need to check the services whether we still have enough
	# newer versions which justifies that old ones are removed.
	# We also need write all the missing files into a separate file for the
	# workflow to use this as exceptions for follow up scripts which without
	# this will just fail.
	local_error = False
	missing_files = []
	for proto_file in c4tfiles:
		if proto_file not in all_proto_files:
			if proto_file not in type_files and "types" not in proto_file:
				# If it's a type file then this is just fine as type files will 
				# be removed as a consequence of services being removed.
				
				# We know now that it's a service file so let's check whether
				# we have 3 newer versions of this file left which justifies the
				# removal of the service file.
				match = file_pattern.match(proto_file)
				if match:
					prefix, version, filename = match.groups()
					key = (prefix, filename)
					if service_versions.get(key) is None:
						print(f"❌ {Colors.RED}ERROR{Colors.RESET}: The service file '{proto_file}' is completely unknown in the current branch. This can only happen in the edge case if a service has been completely removed, which needs to be handled manually!")
						local_error = True
					elif len(service_versions[key]) < MAX_VERSIONS:
						print(f"❌ {Colors.RED}ERROR{Colors.RESET}: The service file '{proto_file}' known in the current branch, but has only {len(service_versions[key])} versions left. This is not enough to justify the removal of the service file!")
						local_error = True
			missing_files.append(proto_file)

	if local_error != True:
		if len(missing_files) > 0:
			# Record the missing files in a file which can be picked up by follow
			# up scripts in order to add these as exceptions.
			with open("missing_files.txt", "w") as f:
				for missing_file in missing_files:
					f.write(f"{directory_path}{missing_file}\n")
			
			print(f"📝 Recorded {len(missing_files)} missing files in 'missing_files.txt'. This can be used by follow up scripts to handle these files as exceptions.")
		else:
			print("✅ No missing files found in the current branch compared to the c4t branch.")

	return local_error


def default_run():
	global_error = False
	fix_needed = {}

	# First we get all the latest proto files
	all_proto_files, latest_proto_files, service_versions, type_files = find_proto_files(directory_path)

	if debug:
		print("🔍 Found the following proto files:")
		for proto_file in all_proto_files:
			if proto_file in latest_proto_files:
				print(f"  ➡️ {Colors.GREEN}{proto_file}{Colors.RESET}")
			else:
				print(f"  ➡️ {Colors.PURPLE}{proto_file}{Colors.RESET}")

	included_by = {}
	included_by_latest = {}

	# Then build up a dependency graph with a dict: { key: <protobuf file> value: [ included by ] }
	for proto_file in all_proto_files:
		if debug:
			print(f"🔍 Checking the file {proto_file} for includes")
		includes = extract_proto_includes(directory_path + proto_file)
		for include in includes:
			if debug:
				print(f"  ➡️ Processing include: {include}")
			if include.startswith("cmp/"): # we're only interested in our includes
				if include not in included_by:
					included_by[include] = [ proto_file ]
				else:
					included_by[include].append(proto_file)

				if proto_file in latest_proto_files:
					if include not in included_by_latest:
						included_by_latest[include] = [ proto_file ]
					else:
						included_by_latest[include].append(proto_file)
	
				if proto_file in latest_proto_files and include not in latest_proto_files:
					if proto_file in type_files and proto_file not in included_by_latest:
						# Edge-case scenario where a file was removed in newer versions
						# With that an old version of this type is checked whether
						# it includes the latest versions of its includes. But as
						# this file shall not do that we just warn instead of erroring out.
						print(f"⚠️ {Colors.YELLOW}WARNING{Colors.RESET}: The type file '{proto_file}' is not including the latest version of '{include}', but as the type file is not included anywhere in the latest version this might be ok.")
					else:
						print(f"❌ {Colors.RED}ERROR{Colors.RESET}: The include '{include}' in '{proto_file}' is not the latest version!")

						if proto_file not in fix_needed:
							fix_needed[proto_file] = [ include ]
						else:
							fix_needed[proto_file].append(include)

						global_error = True

	# Now we have a nice dependency graph-like list to check
	# Let's see whether one of the type proto files is currently not included anywhere
	for proto_file in type_files:
		if debug:
			print(f"🔍 Checking the file {proto_file} for broken/missing dependencies")
		if proto_file not in included_by:
			if not fix:
				print(f"❌ {Colors.RED}ERROR{Colors.RESET}: The type file '{proto_file}' is never included anywhere in the proto files!")
				global_error = True
			else:
				print(f"⚠️ {Colors.YELLOW}WARNING{Colors.RESET}: The type file '{proto_file}' is never included anywhere. Fixing it by removing the file...")
				if remove_file(proto_file):
					fixed_removed_files.append(proto_file)
				global_error = True

		elif proto_file in latest_proto_files and proto_file not in included_by_latest:
			print(f"⚠️ {Colors.YELLOW}WARNING{Colors.RESET}: The type file '{proto_file}' is never included anywhere in the latest proto! This might be ok if the types file is obsolete, but please check!")
			

	if check_and_remove_old_versions(service_versions) == True:
		global_error = True

	if record_missing_files(all_proto_files, type_files, service_versions) == True:
		global_error = True

	if global_error == True:
		print(f"❌ [{Colors.RED}FAIL{Colors.RESET}] There were errors found while doing the dependency check!")
	else:
		print(f"✅ [{Colors.GREEN}PASS{Colors.RESET}] Iteration of dependency check successful!")

	return (global_error, latest_proto_files, fix_needed, included_by_latest)


print("🔍 Checking dependencies")
global_error, latest_proto_files, fix_needed, include_graph = default_run()

## Print of dependency graph if --print-graph is passed:
if print_graph:
	if global_error == True:
		print(f"❌ [{Colors.RED}FAIL{Colors.RESET}] Won't print the graph as there were errors found while doing the dependency check!")
	else:
		print_dependency_graph(include_graph)

## Fix the dependencies if --fix is passed:
if fix:
	# Get the proto files in the c4t branch by calling an external script
	print()
	print("🔧 Trying to fix...")

	max_iterations=20

	for iteration in range(max_iterations): # if it's not fixable in 20 iterations we're cooked anyways so break then
		print
		print(f"🔄 ITERATION #{iteration+1}/{max_iterations}")

		for file, wrong_includes in fix_needed.items():
			search_replace_fixes = []

			print()
			print(f"🔨 The file '{file}' needs a fix because the following includes are wrong:")
			for wrong_include in wrong_includes:
				result = find_latest_version(wrong_include, latest_proto_files)
				if not result: # First, capture the raw result so we don't try to unpack a "False"
					print(f"⛔ [{Colors.RED}FATAL{Colors.RESET}] Unable to find the latest version of {wrong_include}. Exiting")
					sys.exit(2)
				include_prefix, old_include_version, new_include_version, correct_include = result
					
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
			print("⌛ Fix needs another iteration ... ")
		else:
			print("✅ Dependency fix might have succeeded. Please check the results!")
			if len(fixed_new_version_files) > 0 or len(fixed_removed_files) > 0:
				print()
				if len(fixed_new_version_files) > 0:
					print("🆕 Added files by --fix:")
					for added_file in fixed_new_version_files:
						print(f"  🆕 {added_file}")
				if len(fixed_removed_files) > 0:
					print("🗑️ Removed files by --fix:")
					for removed_file in fixed_removed_files:
						print(f"  🗑️ {removed_file}")
				print("⚠️ Don't forget to commit also the new/removed files!")
				print()
			break


if global_error == True:
	print(f"❌ [{Colors.RED}FAIL{Colors.RESET}] Something went wrong while doing the dependency check (or fix) please see above!")
	sys.exit(1)
else:
	print(f"✅ [{Colors.GREEN}PASS{Colors.RESET}] Dependency check/fix successful!")
