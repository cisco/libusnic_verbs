#!/bin/bash

# Full version has format A.B.C.D-E.F, where A and B are major and
# minor version numbers respectively and can be modified in this file.
# Values C through F are all sentinel value 'git' that are overwritten
# by releng when generating an official build.

option="$1"

# edit major/minor version here
VERSION_MAJOR_MINOR=3.0

# edited by releng
VERSION="$VERSION_MAJOR_MINOR.0.0"
BUILD_ID="4.5"

FULL_VERSION="$VERSION-$BUILD_ID"

case "$option" in
	--full)
		echo $FULL_VERSION
		;;
	--version)
		echo $VERSION
		;;
	--build-id)
		echo $BUILD_ID
		;;
	*)
		echo "Usage: $0 {--full|version|build-id}"
		exit 1
esac
