#!/usr/bin/env bash
set -euo pipefail

LIBGIT2_TAG=${LIBGIT2_TAG:-v0.27.10}
MODULE_PATH=$(go list -m -f '{{.Dir}}' github.com/libgit2/git2go/v27 2>/dev/null || true)
if [[ -z "$MODULE_PATH" ]]; then
  if ! go mod download github.com/libgit2/git2go/v27 >/dev/null; then
    echo "Unable to download git2go module." >&2
    exit 1
  fi
  MODULE_PATH=$(go list -m -f '{{.Dir}}' github.com/libgit2/git2go/v27 2>/dev/null || true)
fi
if [[ -z "$MODULE_PATH" ]]; then
  echo "Unable to locate git2go module." >&2
  exit 1
fi

if [[ ! -w "$MODULE_PATH" ]]; then
  chmod -R u+w "$MODULE_PATH"
fi

VENDOR_DIR="$MODULE_PATH/vendor/libgit2"
if [[ ! -d "$VENDOR_DIR/.git" ]]; then
  rm -rf "$VENDOR_DIR"
  git clone --depth 1 --branch "$LIBGIT2_TAG" https://github.com/libgit2/libgit2 "$VENDOR_DIR"
fi

BUILD_ROOT="$MODULE_PATH/static-build"
INSTALL_PREFIX="$BUILD_ROOT/install"
PKGCONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig"
LIBGIT2_PC="$PKGCONFIG_PATH/libgit2.pc"

if [[ -f "$LIBGIT2_PC" ]]; then
  echo "$PKGCONFIG_PATH"
  exit 0
fi

BUILD_DIR="$BUILD_ROOT/build"
mkdir -p "$BUILD_DIR"

cmake -S "$VENDOR_DIR" -B "$BUILD_DIR" \
  -DTHREADSAFE=ON \
  -DBUILD_CLAR=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DUSE_HTTPS=OFF \
  -DUSE_SSH=OFF \
  -DCMAKE_C_FLAGS=-fPIC \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DDEPRECATE_HARD=ON \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build "$BUILD_DIR" --target install

echo "$PKGCONFIG_PATH"
