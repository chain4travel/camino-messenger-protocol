#!/bin/bash

# Colors for output
RED='\033[0;31m'
LRED='\033[1;31m'
YELLOW='\033[0;33m'
LYELLOW='\033[1;33m'
GREEN='\033[0;32m'
LGREEN='\033[1;32m'
BLUE='\033[0;34m'
LBLUE='\033[1;34m'
CYAN='\033[0;36m'
LCYAN='\033[1;36m'
PURPLE='\033[0;35m'
LPURPLE='\033[1;35m'
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

    # First, check basic format (more permissive)
    if ! [[ $tag =~ ^@custom:cmp-service[[:space:]]+type:([[:alnum:]]+)[[:space:]]+routing:([[:alnum:]]+)([[:space:]]+on-chain:([[:alnum:]]+))?$ ]]; then
        invalid_tag_services+=("$filepath:$service_name|$tag - Malformed tag format: must follow '@custom:cmp-service type:<TYPE> routing:<ROUTING> [on-chain:<BOOL>]'")
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

colorize_tag() {
    local tag="$1"

    # Color mappings for different values
    local TYPE_CORE="${LPURPLE}"
    local TYPE_PRODUCT="${LBLUE}"
    local TYPE_SYSTEM="${LRED}"

    local ROUTING_P2P="${LGREEN}"
    local ROUTING_LOCAL="${LYELLOW}"

    local ONCHAIN_TRUE="${LPURPLE}"
    local ONCHAIN_FALSE="${LCYAN}"

    # Extract each part using regex
    if [[ $tag =~ ^(@custom:cmp-service)[[:space:]]+(type:([[:alnum:]]+))[[:space:]]+(routing:([[:alnum:]]+))([[:space:]]+on-chain:([[:alnum:]]+))?$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local type_full="${BASH_REMATCH[2]}"
        local type_value="${BASH_REMATCH[3]}"
        local routing_full="${BASH_REMATCH[4]}"
        local routing_value="${BASH_REMATCH[5]}"
        local onchain_full="${BASH_REMATCH[6]}"
        local onchain_value="${BASH_REMATCH[7]}"

        # Select color for type
        local type_color
        case "$type_value" in
        "core") type_color="$TYPE_CORE" ;;
        "product") type_color="$TYPE_PRODUCT" ;;
        "system") type_color="$TYPE_SYSTEM" ;;
        *) type_color="$RED" ;; # Invalid value
        esac

        # Select color for routing
        local routing_color
        case "$routing_value" in
        "p2p") routing_color="$ROUTING_P2P" ;;
        "local") routing_color="$ROUTING_LOCAL" ;;
        *) routing_color="$RED" ;; # Invalid value
        esac

        # Select color for on-chain
        local onchain_color
        case "$onchain_value" in
        "true") onchain_color="$ONCHAIN_TRUE" ;;
        "false") onchain_color="$ONCHAIN_FALSE" ;;
        *) onchain_color="$RED" ;; # Invalid value
        esac

        # Build the colored string
        local result="${BOLD}$prefix${NC} ${type_color}${type_full}${NC} ${routing_color}${routing_full}${NC}"
        #local result="$prefix type:${type_color}${type_value}${NC} routing:${routing_color}${routing_value}${NC}"
        if [ ! -z "$onchain_full" ]; then
            #result+=" on-chain:${onchain_color}${onchain_value}${NC}"
            result+=" ${onchain_color}on-chain:${onchain_value}${NC}"
        fi

        echo "$result"
    else
        # If the tag doesn't match the expected format, return it unchanged
        echo "$tag"
    fi
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
            echo -e "       ${YELLOW}${clean_tag}${NC} ${RED}${error_msg}${NC}"
        else
            echo -e "  ${CYAN}${filepath}${NC}"
            echo -e "    └─ ${BOLD}$service${NC}"
            #echo -e "       ${GREEN}${tag}${NC} ${SUCCESS}"
            echo -e "       $(colorize_tag "$tag")"
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
echo "================================================="
if [ ${#no_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found without tags"
else
    for service in "${no_tag_services[@]}"; do
        format_service_output "$service"
    done
    EXIT_CODE=1
fi

echo -e "\n${BYELLOW}${WARNING} Services with invalid @custom:cmp-service tag:${NC}"
echo "================================================="
if [ ${#invalid_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found with invalid tags"
else
    for service in "${invalid_tag_services[@]}"; do
        format_service_output "$service"
    done

    echo -e "\n  ${INFO} Valid values: type=\"${valid_types[@]}\" routing=\"${valid_routing[@]}\" on-chain=\"${valid_onchain[@]}\""
    EXIT_CODE=1
fi

echo -e "\n${LGREEN}${SUCCESS} Services with valid @custom:cmp-service tag:${NC}"
echo "================================================="
if [ ${#valid_tag_services[@]} -eq 0 ]; then
    echo -e "  ${INFO} No services found with valid tags"
else
    for service in "${valid_tag_services[@]}"; do
        format_service_output "$service"
    done
fi

# Print summary
echo -e "\n${BLUE}${INFO} Summary:${NC}"
echo "================================================="
echo -e "${RED}${ERROR} Missing tags: ${#no_tag_services[@]}${NC}"
echo -e "${YELLOW}${WARNING} Invalid tags: ${#invalid_tag_services[@]}${NC}"
echo -e "${GREEN}${SUCCESS} Valid tags: ${#valid_tag_services[@]}${NC}"
echo -e "Total services: $((${#no_tag_services[@]} + ${#invalid_tag_services[@]} + ${#valid_tag_services[@]}))"
exit $EXIT_CODE
