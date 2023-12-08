#!/bin/bash

BIN="/usr/local/bin"
GITHUB_API_URL="https://api.github.com/repos/bufbuild/buf/releases/latest"
GITHUB_RELEASES_URL="https://api.github.com/repos/bufbuild/buf/releases"

# Function to fetch latest version
fetch_latest_version() {
    curl -sSL $GITHUB_API_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//'
}

# Function to list all versions
list_versions() {
    curl -sSL $GITHUB_RELEASES_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Argument parsing
VERSION=""
LIST_VERSIONS=false
for i in "$@"
do
case $i in
    --version=*)
    VERSION="${i#*=}"
    shift
    ;;
    --list)
    LIST_VERSIONS=true
    shift
    ;;
    *)
    # unknown option
    ;;
esac
done

# Logic for listing versions
if [ "$LIST_VERSIONS" = true ]; then
    list_versions
    exit 0
fi

# Set the default version to the latest if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(fetch_latest_version)
fi

# Installation
echo "Installing buf version $VERSION..."
curl -sSL "https://github.com/bufbuild/buf/releases/download/v${VERSION}/buf-$(uname -s)-$(uname -m)" \
-o "${BIN}/buf" && \
chmod +x "${BIN}/buf"

