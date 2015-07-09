#!/bin/bash
set -e
cd $(dirname "${BASH_SOURCE[0]}")
ROOT="$(pwd)"

echo $ROOT

ARCH="$1" 
REPO_DIR="libvpx"
BUILD_DIR="libvpx-ios-build"
EXTRA_CFLAGS="-fembed-bitcode-marker -miphoneos-version-min=8.0"
GIT_REPO="https://github.com/tidwall/libvpx"
GIT_TAG=master #"v1.4.0"

# clean command
if [ "$2" == "clean" ]; then
	rm -rf "$BUILD_DIR" "$REPO_DIR"
	exit
fi

# git clone
if [ ! -d "$REPO_DIR" ]; then
	rm -rf "$GIT_REPO.tmp"
	git clone "$GIT_REPO" "$REPO_DIR.tmp"
	mv "$REPO_DIR.tmp" "$REPO_DIR"
fi

# git checkout
cd $REPO_DIR
CUR_GIT_TAG=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
if [ "$CUR_GIT_TAG" != "$GIT_TAG" ]; then
	git checkout "$GIT_TAG"
fi
cd ..

mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

build(){
	if [ ! -f "$1/libvpx.a" ]; then
		mkdir -p $1 && cd $1
		"$ROOT/$REPO_DIR/configure" --target=$2 --disable-examples --disable-docs --extra-cflags="$EXTRA_CFLAGS"
		make
		cd ../
	fi
}

build "arm64" "arm64-darwin-gcc"

exit




mkdir -p $BUILD_DIR && cd $BUILD_DIR



build "arm64" "arm64-darwin-gcc"
build "armv7" "armv7-darwin-gcc"
build "armv7s" "armv7s-darwin-gcc"
build "x86_64" "x86_64-iphonesimulator-gcc"
