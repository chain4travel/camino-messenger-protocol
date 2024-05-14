#!/bin/env bash
#
# Generates diagrams from the given path, walking through the path
# and running protodot for each .proto file.

PROTODOT="protodot"
GENERATED_DIR="${1:-gen}"
PROTO_DIR="${2:-proto/cmp}"
PROTODOT_DIR="${3:-diagrams}"

declare -a BIG_ENUMS=(
    "country.proto"
    "currency.proto"
    "language.proto"
    "price_type.proto"
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
    /enum [^ ]+ {/ { print_flag=0; enum_count=0; print; next; }
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

INCLUDE_PROTO_DIR=${PROTO_DIR}/google/protobuf

# Get TIMESTAMP google/protobuf/timestamp.proto
TIMESTAMP_FILENAME=${INCLUDE_PROTO_DIR}/timestamp.proto
mkdir -p ${INCLUDE_PROTO_DIR}
curl https://raw.githubusercontent.com/protocolbuffers/protobuf/main/src/google/protobuf/timestamp.proto > $TIMESTAMP_FILENAME

# Get Empty proto file
EMPTY_FILENAME=${INCLUDE_PROTO_DIR}/empty.proto
curl https://raw.githubusercontent.com/protocolbuffers/protobuf/main/src/google/protobuf/empty.proto > $EMPTY_FILENAME

# Get Wrappers proto file
WRAPPERS_FILENAME=${INCLUDE_PROTO_DIR}/wrappers.proto
curl https://raw.githubusercontent.com/protocolbuffers/protobuf/main/src/google/protobuf/wrappers.proto > $WRAPPERS_FILENAME

# Generate diagrams
for protofile in `find ${PROTO_DIR} -type f -name '*.proto'`; do
    # Set proto file dir
    protofile_dir=${GENERATED_DIR}/${PROTODOT_DIR}/$(dirname ${protofile})

    # Create proto file dir if it doesn't exist
    mkdir -p ${protofile_dir}

    # Create the protodot diagram
    ${PROTODOT} -generated ${protofile_dir} -src ${protofile} -output $(basename ${protofile})

    # Create a scaled version of the diagram
    svg_filename="${GENERATED_DIR}/${PROTODOT_DIR}/${protofile}.dot.svg"
    xs_filename="${GENERATED_DIR}/${PROTODOT_DIR}/${protofile}.dot.xs.svg"
    rsvg-convert "${svg_filename}" -w 850 -f svg -o "${xs_filename}"
done

# When generating finished, revert the truncated big enums
for truncated_file in "${TRUNCATE[@]}"; do
    # Revert the truncated files back
    revert_protobuf ${truncated_file}
done

# Clean up INCLUDE_PROTO_DIR
rm -rfv ${INCLUDE_PROTO_DIR}