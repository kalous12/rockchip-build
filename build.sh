#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")"

mkdir -p build/logs
exec > >(tee "build/logs/build-$(date +"%Y%m%d%H%M%S").log") 2>&1

VENDOR=lubancat-rk3568
BOARD=lubancat2

for file in build/linux-image-*.deb; do
    if [ ! -e "$file" ]; then
        eval "${DOCKER}" ./scripts/build-kernel.sh
    fi
done

for file in build/u-boot-*.deb; do
    if [ ! -e "$file" ]; then
        eval "${DOCKER}" ./scripts/build-uboot.sh -f
    fi
done

if [ -d "build/rootfs" ]; then
    rm -r build/rootfs
fi

if [ -d "images" ]; then
    rm -r images
fi

./scripts/build-rootfs.sh
./scripts/config-image.sh

exit 0
