BINARY          := bin/gtm
BASE_VERSION    := 1.4.0
VERSION         := $(shell git describe --tags --match 'v*' --dirty 2>/dev/null)
COMMIT          := $(shell git rev-parse --short HEAD 2>/dev/null)
DEV_SUFFIX     ?= 0
ifeq ($(strip $(VERSION)),)
VERSION         := $(BASE_VERSION)
ifeq ($(DEV_SUFFIX),1)
ifneq ($(strip $(COMMIT)),)
VERSION         := $(VERSION)-dev-$(COMMIT)
endif
endif
endif
LDFLAGS         := -ldflags "-X main.Version=$(VERSION)"
BUILD_TAGS     ?= static
TEST_OPTIONS   ?=
PKG_CONFIG_FILE := .cache/libgit2_pkgconfig
GOCACHE        ?= $(CURDIR)/.gocache
GOMODCACHE     ?= $(CURDIR)/.gomodcache
ENV_TOOLS       = GOCACHE=$(GOCACHE) GOMODCACHE=$(GOMODCACHE)
ENV_VARS        = PKG_CONFIG_PATH=$$(cat $(PKG_CONFIG_FILE)):$${PKG_CONFIG_PATH} $(ENV_TOOLS)
HOME_DIR       ?= $(CURDIR)/.tmp-home
PKGS            = ./...

.DEFAULT_GOAL := build

.PHONY: build debug profile debug-profile test test-verbose clean deps libgit2 tidy install fmt lint

deps: tidy libgit2

build: libgit2
	@mkdir -p $(dir $(BINARY))
	@$(ENV_VARS) go build -tags '$(BUILD_TAGS)' $(LDFLAGS) -o $(BINARY)

debug: BUILD_TAGS += debug
debug: build

profile: BUILD_TAGS += profile
profile: build

debug-profile: BUILD_TAGS += debug profile
debug-profile: build

test: libgit2
	@mkdir -p $(HOME_DIR)
	@HOME=$(HOME_DIR) GTM_HOME=$(HOME_DIR) $(ENV_VARS) go test $(TEST_OPTIONS) -tags '$(BUILD_TAGS)' $(PKGS)

test-verbose: TEST_OPTIONS += -v
test-verbose: test

install: libgit2
	@$(ENV_VARS) go install -tags '$(BUILD_TAGS)' $(LDFLAGS)

fmt:
	go fmt $(PKGS)

lint:
	go vet -tags '$(BUILD_TAGS)' $(PKGS)

clean:
	-@chmod -R u+w $(GOMODCACHE) 2>/dev/null || true
	rm -rf $(BINARY) $(PKG_CONFIG_FILE) $(GOCACHE) $(GOMODCACHE) $(HOME_DIR)

libgit2: $(PKG_CONFIG_FILE)

$(PKG_CONFIG_FILE):
	@mkdir -p $(dir $@)
	@echo "Preparing libgit2 (this may take a few minutes on first run)..."
	@PKG_PATH=$$( $(ENV_TOOLS) script/setup_libgit2.sh ) && echo $$PKG_PATH > $@

tidy:
	go mod tidy
