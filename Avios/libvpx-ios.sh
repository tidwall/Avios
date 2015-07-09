#!/bin/bash
set -e
cd $(dirname "${BASH_SOURCE[0]}")
ROOT="$(pwd)"
ARCH="$1"
if [ "$ARCH" == "" ]; then
	echo "usage: ${BASH_SOURCE[0]} [armv7 arm64 armv7s i386]"
	exit 1
fi
REPO_DIR="libvpx"
BUILD_DIR="libvpx-ios-build"
GIT_REPO="https://github.com/tidwall/libvpx"
GIT_TAG="xcode7"

# clean command
if [ "$2" == "clean" ]; then
	rm -rf "$BUILD_DIR"
	exit
fi

# git clone
if [ ! -d "$REPO_DIR" ]; then
	rm -rf "$REPO_DIR.tmp"
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

alter(){
	if [ "$1" == "armv7" ]; then
		sed '/^ASFLAGS/ d' < Makefile > Makefile.t
		rm Makefile && mv Makefile.t Makefile
	fi
}

build(){
	if [ ! -f "$1/libvpx.a" ]; then
		rm -rf $1 && mkdir -p $1 && cd $1
		"$ROOT/$REPO_DIR/configure" --target=$2 --disable-vp9 --disable-vp8-encoder --extra-cflags="$EXTRA_CFLAGS"
		alter "$ARCH"
		make -j
		cd ../
	fi
}

if [ "$ARCH" == "armv7" ] || [ "$ARCH" == "armv7s" ] || [ "$ARCH" == "arm64" ]; then
	EXTRA_CFLAGS="-fembed-bitcode-marker -miphoneos-version-min=6.0"
	build "armv7"	"armv7-darwin-gcc"
	build "armv7s"	"armv7s-darwin-gcc"
	build "arm64"	"arm64-darwin-gcc"
elif [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "i386" ]; then
	build "i386"	"x86-iphonesimulator-gcc"
	build "x86_64"	"x86_64-iphonesimulator-gcc"
else
	echo "Invalid arch: $ARCH"
	exit 1
fi
