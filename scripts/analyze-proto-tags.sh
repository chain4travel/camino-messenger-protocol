#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
LGREEN='\033[1;32m'
BLUE='\033[0;34m'
LBLUE='\033[1;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Emojis
WARNING="🚫"
ERROR="❌"
SUCCESS="✅"
INFO="ℹ️ "
FOLDER="📁"
MAGNIFIER="🔍"

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

    # Check if the tag matches the expected format (including strict on-chain value check)
    if ! [[ $tag =~ ^@custom:cmp-service[[:space:]]+type:([[:alnum:]]+)[[:space:]]+routing:([[:alnum:]]+)([[:space:]]+on-chain:(true|false))?$ ]]; then
        invalid_tag_services+=("$filepath:$service_name|$tag - Malformed tag format")
        return
    fi

    # Extract values
    type="${BASH_REMATCH[1]}"
    routing="${BASH_REMATCH[2]}"
    onchain="${BASH_REMATCH[4]:-false}"

    # Validate type
    if [[ ! " ${valid_types[@]} " =~ " ${type} " ]]; then
        invalid_tag_services+=("$filepath:$service_name|$tag - Invalid type: $type")
        return
    fi

    # Validate routing
    if [[ ! " ${valid_routing[@]} " =~ " ${routing} " ]]; then
        invalid_tag_services+=("$filepath:$service_name|$tag - Invalid routing: $routing")
        return
    fi

    # Validate on-chain if present
    if [ ! -z "$onchain" ] && [[ ! " ${valid_onchain[@]} " =~ " ${onchain} " ]]; then
        invalid_tag_services+=("$filepath:$service_name|$tag - Invalid on-chain value: $onchain")
        return
    fi

    # If we get here, the tag is valid
    valid_tag_services+=("$filepath:$service_name|$tag")
}

scan_proto_files() {
    local dir="$1"

    echo -e "${BLUE}${MAGNIFIER} Scanning directory: ${CYAN}$dir${NC}"
    echo "----------------------------------------"

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

format_service_output() {
    local input="$1"
    local filepath="${input%%:*}"
    local rest="${input#*:}"

    # Check if the input contains a tag (has a | separator)
    if [[ "$rest" == *"|"* ]]; then
        local service="${rest%%|*}"
        local tag="${rest#*|}"

        # For valid services, don't try to extract error message
        if [[ "$tag" =~ .*" - ".* ]]; then
            local error_msg=" - ${tag#* - }"
            local clean_tag="${tag%% - *}"

            echo -e "  ${CYAN}${filepath}${NC}"
            echo -e "    └─ ${BOLD}$service${NC}"
            echo -e "       ${clean_tag}${RED}${error_msg}${NC}"
        else
            echo -e "  ${CYAN}${filepath}${NC}"
            echo -e "    └─ ${BOLD}$service${NC}"
            echo -e "       ${GREEN}${tag}${NC} ${SUCCESS}"
        fi
    else
        # No tag case
        local service="$rest"
        echo -e "  ${CYAN}${filepath}${NC}"
        echo -e "    └─ ${BOLD}$service${NC}"
    fi
}

# Main execution
if [ "$#" -ne 1 ]; then
    echo -e "${ERROR} Usage: $0 <directory>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo -e "${ERROR} Error: Directory $1 does not exist"
    exit 1
fi

# Scan the directory
scan_proto_files "$1"

# Print results
echo -e "\n${RED}${ERROR} Services without @custom:cmp-service tag:${NC}"
echo "=========================================="
if [ ${#no_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found without tags"
else
    for service in "${no_tag_services[@]}"; do
        format_service_output "$service"
    done
fi

echo -e "\n${YELLOW}${WARNING} Services with invalid @custom:cmp-service tag:${NC}"
echo "=========================================="
if [ ${#invalid_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found with invalid tags"
else
    for service in "${invalid_tag_services[@]}"; do
        format_service_output "$service"
    done
fi

echo -e "\n${LGREEN}${SUCCESS} Services with valid @custom:cmp-service tag:${NC}"
echo "=========================================="
if [ ${#valid_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found with valid tags"
else
    for service in "${valid_tag_services[@]}"; do
        format_service_output "$service"
    done
fi

# Print summary
echo -e "\n${BLUE}${INFO} Summary:${NC}"
echo "=========================================="
echo -e "${RED}${ERROR} Missing tags: ${#no_tag_services[@]}${NC}"
echo -e "${YELLOW}${WARNING} Invalid tags: ${#invalid_tag_services[@]}${NC}"
echo -e "${GREEN}${SUCCESS} Valid tags: ${#valid_tag_services[@]}${NC}"
echo -e "Total services: $((${#no_tag_services[@]} + ${#invalid_tag_services[@]} + ${#valid_tag_services[@]}))"
