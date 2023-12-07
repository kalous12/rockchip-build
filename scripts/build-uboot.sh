#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [[ $1 = "-f" ]]; then
    echo "rebuild"
    if [ -d u-boot-"${VENDOR}" ]; then
        rm -r u-boot-"${VENDOR}"
    fi
fi

if [ ! -d u-boot-"${VENDOR}" ]; then
    # shellcheck source=/dev/null
    source ../packages/u-boot/u-boot-"${VENDOR}"/debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" u-boot-"${VENDOR}"
    git -C u-boot-"${VENDOR}" checkout "${COMMIT}"
    cp -r ../packages/u-boot/u-boot-"${VENDOR}"/debian u-boot-"${VENDOR}"
    cd u-boot-"${VENDOR}"

    if [ -f debian/patches/series ] ;then
       for i in `cat debian/patches/series`;
       do patch -p1 < debian/patches/"$i";done
    fi
fi

# Compile u-boot into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes
