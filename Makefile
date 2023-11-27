# Generation Settings
GENERATED_DIR = gen
MODULLE_DIR = proto/cmp
PROTOC = protoc

# Protodot diagrams
PROTODOT = protodot
PROTODOT_DIR = diagrams

# Colors
GREEN=\033[92m
BLUE=\033[94m
RESET=\033[0m

# Default target
all: diagrams

# Generate protodot diagrams
diagrams: ${GENERATED_DIR}/${PROTODOT_DIR}
	@echo "${GREEN}Generating Protodot Diagrams files${RESET}"
	./scripts/generate_protodot.sh ${GENERATED_DIR} ${MODULLE_DIR} ${PROTODOT_DIR}

# Create necessary directories if they do not exist
${GENERATED_DIR}/${PROTODOT_DIR}:
	mkdir -p $@

clean:
	rm -rfv ${GENERATED_DIR}/*

sabledocs:
	protoc proto/cmp/*/*.proto -o descriptor.pb --include_source_info
	sabledocs
	mv sabledocs_output ${GENERATED_DIR}/
	rm -fv descriptor.pb

# Mark commands as phony so make knows they're not associated with files
.PHONY: all clean diagrams sabledocs
