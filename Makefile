BINARY         = bin/gtm
VERSION        = 0.0.0-dev
COMMIT         = $(shell git show -s --format='%h' HEAD)
STRIP_LDFLAGS ?= -s -w
LDFLAGS        = -ldflags "$(strip $(STRIP_LDFLAGS) -X main.Version=$(VERSION)-$(COMMIT))"
GOPATH_DIR    ?= $(CURDIR)/.gopath
REPO_LINK      := $(GOPATH_DIR)/src/github.com/git-time-metric/gtm
GO_ENV        ?= GO111MODULE=off GOPATH=$(GOPATH_DIR)
GIT2GO_VERSION = v27
GIT2GO_PATH    = $(GOPATH_DIR)/src/github.com/libgit2/git2go
LIBGIT2_PATH   = $(GIT2GO_PATH)/vendor/libgit2

$(shell mkdir -p $(dir $(REPO_LINK)) && { ln -snf $(CURDIR) $(REPO_LINK) 2>/dev/null || true; })

PKGS           = $(shell cd $(REPO_LINK) && $(GO_ENV) go list ./... | grep -v vendor)
BUILD_TAGS     = static

.PHONY: vendor-sync
vendor-sync:
	go run ./script/sync_vendor.go

build: vendor-sync
	cd $(REPO_LINK) && $(GO_ENV) go build --tags '$(BUILD_TAGS)' $(LDFLAGS) -o $(CURDIR)/$(BINARY)

debug: STRIP_LDFLAGS =
debug: BUILD_TAGS += debug
debug: build

profile: STRIP_LDFLAGS =
profile: BUILD_TAGS += profile
profile: build

debug-profile: STRIP_LDFLAGS =
debug-profile: BUILD_TAGS += debug profile
debug-profile: build

test: vendor-sync
	@cd $(REPO_LINK) && $(GO_ENV) go test $(TEST_OPTIONS) --tags '$(BUILD_TAGS)' $(PKGS) | grep --colour -E "FAIL|$$"

test-verbose: TEST_OPTIONS += -v
test-verbose: test


lint: vendor-sync
	-@$(call color_echo, 4, "\nGo Vet"); \
		cd $(REPO_LINK) && $(GO_ENV) go vet --all --tags '$(BUILD_TAGS)' $(PKGS)
	-@$(call color_echo, 4, "\nError Check"); \
		errcheck -ignoretests -tags '$(BUILD_TAGS)' $(PKGS)
	-@$(call color_echo, 4, "\nIneffectual Assign"); \
		ineffassign ./
	-@$(call color_echo, 4, "\nStatic Check"); \
		staticcheck --tests=false --tags '$(BUILD_TAGS)' $(PKGS)
	-@$(call color_echo, 4, "\nGo Simple"); \
		gosimple --tests=false --tags '$(BUILD_TAGS)' $(PKGS)
	-@$(call color_echo, 4, "\nUnused"); \
		unused --tests=false --tags '$(BUILD_TAGS)' $(PKGS)
	-@$(call color_echo, 4, "\nGo Lint"); \
		golint $(PKGS)
	-@$(call color_echo, 4, "\nGo Format"); \
		cd $(REPO_LINK) && $(GO_ENV) go fmt $(PKGS)
	-@$(call color_echo, 4, "\nLicense Check"); \
		ag --go -L license . |grep -v vendor/

install: vendor-sync
	cd $(REPO_LINK) && $(GO_ENV) go install --tags '$(BUILD_TAGS)' $(LDFLAGS)

clean:
	cd $(REPO_LINK) && $(GO_ENV) go clean
	rm -f bin/*

git2go-install:
	[[ -d $(GIT2GO_PATH) ]] || git clone https://github.com/libgit2/git2go.git $(GIT2GO_PATH) && \
	cd ${GIT2GO_PATH} && \
	git pull && \
	git checkout -qf $(GIT2GO_VERSION) && \
	git submodule update --init

git2go: git2go-install
	cd $(LIBGIT2_PATH) && python3 -c "from pathlib import Path; p=Path('deps/zlib/zutil.h'); needle='#if defined(MACOS) || defined(TARGET_OS_MAC)\n'; repl='#if defined(MACOS) || (defined(TARGET_OS_MAC) && !defined(__APPLE__))\n'; txt=p.read_text(); p.write_text(txt.replace(needle, repl, 1)) if needle in txt and repl not in txt else None"
	cd $(LIBGIT2_PATH) && \
	mkdir -p install/lib && \
	mkdir -p build && \
	cd build && \
	cmake -DTHREADSAFE=ON \
		  -DBUILD_CLAR=OFF \
		  -DBUILD_SHARED_LIBS=OFF \
		  -DCMAKE_C_FLAGS='-fPIC -DTARGET_OS_MAC=0' \
		  -DUSE_SSH=OFF \
		  -DCURL=OFF \
		  -DUSE_HTTPS=OFF \
		  -DUSE_BUNDLED_ZLIB=ON \
		  -DCMAKE_BUILD_TYPE="Release" \
		  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		  -DCMAKE_INSTALL_PREFIX=../install \
		  .. && \
	cmake --build .

git2go-clean:
	[[ -d $(GIT2GO_PATH) ]] && rm -rf $(GIT2GO_PATH)

define color_echo
      @tput setaf $1
      @echo $2
      @tput sgr0
endef

.PHONY: build test vet fmt install clean git2go-install git2go-build all-tags profile debug
