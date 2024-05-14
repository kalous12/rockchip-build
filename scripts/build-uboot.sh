#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# 脚本选项

if [ ! -d "${UBOOT_SYSTEM}" ]; then
    # shellcheck source=/dev/null
    source ../packages/u-boot/"${UBOOT_SYSTEM}"/debian/upstream
    git clone --single-branch --progress -b "${BRANCH}" "${GIT}" "${UBOOT_SYSTEM}"
    git -C "${UBOOT_SYSTEM}" checkout "${COMMIT}"
    cp -r ../packages/u-boot/"${UBOOT_SYSTEM}"/debian "${UBOOT_SYSTEM}"
    cd "${UBOOT_SYSTEM}"

    if [ -f debian/patches/series ] ;then
       for i in `cat debian/patches/series`;
       do patch -p1 < debian/patches/"$i";done
    fi
fi

# Compile u-boot into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc

rm -f ../*.buildinfo ../*.changes
