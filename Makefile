APP_NAME := Craftorio
SRC_DIR := src
BIN_DIR := bin
DEBUG_BIN := $(BIN_DIR)/debug/$(APP_NAME)
RELEASE_BIN := $(BIN_DIR)/release/$(APP_NAME)

ODIN_FLAGS ?= 
# -sanitize:address
ODIN_DEBUG_FLAGS := -debug ${ODIN_FLAGS} 
ODIN_RELEASE_FLAGS := -o:speed -no-bounds-check -disable-assert ${ODIN_FLAGS}
ODIN := odin

.PHONY: all
all: debug release

.PHONY: debug
debug:
	@echo "Building debug ..."
	@mkdir -p $(BIN_DIR)/debug

	$(ODIN) build $(SRC_DIR) -out:$(DEBUG_BIN) ${ODIN_DEBUG_FLAGS}
	@echo "Built: $(DEBUG_BIN)"

.PHONY: release
release:
	@echo "Building release ..."
	@mkdir -p $(BIN_DIR)/release
	$(ODIN) build $(SRC_DIR) -out:$(RELEASE_BIN) -o:speed ${ODIN_FLAGS}
	@echo "Built: $(RELEASE_BIN)"

.PHONY: run
run: debug
	@echo "🐢 Running $(DEBUG_BIN)..."
	@$(DEBUG_BIN)

.PHONY: run-release
run-release: release
	@echo "🐇 Running $(RELEASE_BIN)..."
	@$(RELEASE_BIN)

.PHONY: clean
clean:
	rm -rf $(BIN_DIR)

