#!/bin/env bash
#
# Generates diagrams from the given path, walking through the path
# and running protodot for each .proto file.

PROTODOT="protodot"
GENERATED_DIR="${1:-gen}"
PROTO_DIR="${2:-proto/cmp}"
PROTODOT_DIR="${3:-diagrams}"
VERSION="v1alpha1"

declare -a BIG_ENUMS=(
    "country.proto"
    "currency.proto"
    "language.proto"
)

declare -a TRUNCATE=()

# Usage: shorten_protobuf "path/to/country.proto"
shorten_protobuf() {
    local filename="$1"

    # Check if the file exists
    if [[ ! -f "$filename" ]]; then
        echo "File not found: $filename"
        return 1
    fi

    # Create a backup of the original file
    cp -v "$filename" "${filename}.bak"

    # Process the file
    awk '
    BEGIN { print_flag=1; enum_count=0; }
    /enum [^ ]+ {/ { print_flag=0; print; next; }
    /}/ { if (print_flag == 0) { print "  X_TRUNCATED_X = 999;"; print; print_flag=1; } else { print; } next; }
    { if (print_flag) { print; } else { if (enum_count < 7) { print; enum_count++; } } }
    ' "$filename" > "${filename}.tmp"

    # Replace original file with modified file
    mv -v "${filename}.tmp" "$filename"
}

# Usage: revert_protobuf "path/to/country.proto"
revert_protobuf() {
    local filename="$1"

    # Check if the backup file exists
    local backup_filename="${filename}.bak"
    if [[ ! -f "$backup_filename" ]]; then
        echo "Backup file not found: $backup_filename"
        return 1
    fi

    # Replace the modified file with the backup
    mv -v "$backup_filename" "$filename"
}

# Collect big enum files
for protofile in `find ${PROTO_DIR} -type f -name '*.proto'`; do
    if [[ ${BIG_ENUMS[@]} =~ $(basename ${protofile}) ]]; then
        # Found a big enum, add to TRUNCATE
        TRUNCATE+=(${protofile})
        # Then truncate the file
        shorten_protobuf ${protofile}
    fi
done

# Generate diagrams
for protofile in `find ${PROTO_DIR} -type f -name '*.proto'`; do
    # Set proto file dir
    protofile_dir=${GENERATED_DIR}/${PROTODOT_DIR}/$(dirname ${protofile})

    # Create proto file dir if it doesn't exist
    mkdir -p ${protofile_dir}

    # Create the protodot diagram
    ${PROTODOT} -generated ${protofile_dir} -src ${protofile} -output $(basename ${protofile})
done

# When generating finished, revert the truncated big enums
for truncated_file in "${TRUNCATE[@]}"; do
    # Revert the truncated files back
    revert_protobuf ${truncated_file}
done