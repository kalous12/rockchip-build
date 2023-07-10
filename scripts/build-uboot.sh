#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# if [[ -z ${VENDOR} ]]; then
#     echo "Error: VENDOR is not set"
#     exit 1
# fi

VENDOR=mainline-v2023.04

if [ ! -d u-boot-"${VENDOR}" ]; then
    # shellcheck source=/dev/null
    source ../packages/u-boot/u-boot-"${VENDOR}"/debian/upstream
    if [ ${COMMIT} ]; then
        echo COMMIT=${COMMIT}
        git clone --single-branch --progress -b "${BRANCH}" "${GIT}" u-boot-"${VENDOR}"
        git -C u-boot-"${VENDOR}" checkout "${COMMIT}"
        cp -r ../packages/u-boot-"${VENDOR}"/debian u-boot-"${VENDOR}"
    else
        git clone --depth=1 --progress -b "${BRANCH}" "${GIT}" u-boot-"${VENDOR}"
        cp -r ../packages/u-boot/u-boot-"${VENDOR}"/debian u-boot-"${VENDOR}"
    fi
fi
cp -r ../packages/u-boot/u-boot-"${VENDOR}"/debian u-boot-"${VENDOR}"
cd u-boot-"${VENDOR}"

# Compile u-boot into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes
