#!/bin/env bash
#
# Generates diagrams from the given path, walking through the path
# and running protodot for each .proto file.

PROTODOT="protodot"
GENERATED_DIR="${1:-gen}"
TCM_DIR="${2:-proto/cmp}"
PROTODOT_DIR="${3:-diagrams}"
VERSION="v1alpha1"

for pkg in `ls -1 ${TCM_DIR}`; do
    for protofile in `ls -1 ${TCM_DIR}/${pkg}/${VERSION}`; do
        mkdir -p ${GENERATED_DIR}/${PROTODOT_DIR}/${pkg}/${VERSION}
        ${PROTODOT} -generated ${GENERATED_DIR}/${PROTODOT_DIR}/${pkg}/${VERSION} -src ${TCM_DIR}/${pkg}/${VERSION}/${protofile} -output ${protofile}
    done
done
