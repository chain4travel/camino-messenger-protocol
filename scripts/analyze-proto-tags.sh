#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Valid values
valid_types=("core" "product" "system")
valid_routing=("p2p" "local")
valid_onchain=("true" "false")

# Initialize arrays for different categories
declare -a no_tag_services
declare -a invalid_tag_services
declare -a valid_tag_services

check_service() {
    local file="$1"
    local service_name="$2"
    local tag="$3"
    local filepath="$4"

    # If no tag is present
    if [ -z "$tag" ]; then
        no_tag_services+=("$filepath:$service_name")
        return
    fi

    # Check if the tag matches the expected format
    if ! [[ $tag =~ @custom:cmp-service[[:space:]]+type:([[:alnum:]]+)[[:space:]]+routing:([[:alnum:]]+)([[:space:]]+on-chain:(true|false))? ]]; then
        invalid_tag_services+=("$filepath:$service_name - Malformed tag format")
        return
    fi

    # Extract values
    type="${BASH_REMATCH[1]}"
    routing="${BASH_REMATCH[2]}"
    onchain="${BASH_REMATCH[4]:-false}"

    # Validate type
    if [[ ! " ${valid_types[@]} " =~ " ${type} " ]]; then
        invalid_tag_services+=("$filepath:$service_name - Invalid type: $type")
        return
    fi

    # Validate routing
    if [[ ! " ${valid_routing[@]} " =~ " ${routing} " ]]; then
        invalid_tag_services+=("$filepath:$service_name - Invalid routing: $routing")
        return
    fi

    # Validate on-chain if present
    if [ ! -z "$onchain" ] && [[ ! " ${valid_onchain[@]} " =~ " ${onchain} " ]]; then
        invalid_tag_services+=("$filepath:$service_name - Invalid on-chain value: $onchain")
        return
    fi

    # If we get here, the tag is valid
    valid_tag_services+=("$filepath:$service_name")
}

scan_proto_files() {
    local dir="$1"

    # Find all .proto files recursively
    while IFS= read -r -d '' file; do
        while IFS= read -r line; do
            # Check for service definition
            if [[ $line =~ ^[[:space:]]*service[[:space:]]+([[:alnum:]]+)[[:space:]]*\{ ]]; then
                service_name="${BASH_REMATCH[1]}"
                # Get the line before service definition
                prev_line=$(grep -B 1 "^[[:space:]]*service[[:space:]]\+${service_name}[[:space:]]*{" "$file" | head -n 1)

                # Check if previous line contains the custom tag
                if [[ $prev_line =~ ///[[:space:]]*(@custom:cmp-service.*) ]]; then
                    check_service "$file" "$service_name" "${BASH_REMATCH[1]}" "$file"
                else
                    check_service "$file" "$service_name" "" "$file"
                fi
            fi
        done <"$file"
    done < <(find "$dir" -type f -name "*.proto" -print0)
}

# Main execution
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "Error: Directory $1 does not exist"
    exit 1
fi

# Scan the directory
scan_proto_files "$1"

# Print results
echo -e "\n${RED}Services without @custom:cmp-service tag:${NC}"
printf '%s\n' "${no_tag_services[@]}" | sort

echo -e "\n${YELLOW}Services with invalid @custom:cmp-service tag:${NC}"
printf '%s\n' "${invalid_tag_services[@]}" | sort

echo -e "\n${GREEN}Services with valid @custom:cmp-service tag:${NC}"
printf '%s\n' "${valid_tag_services[@]}" | sort

# Print summary
echo -e "\nSummary:"
echo "Total services without tag: ${#no_tag_services[@]}"
echo "Total services with invalid tag: ${#invalid_tag_services[@]}"
echo "Total services with valid tag: ${#valid_tag_services[@]}"
