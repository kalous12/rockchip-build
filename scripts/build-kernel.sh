#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..

mkdir -p build && cd build

if [ ! -d linux ]; then
    # git clone --depth=1 --progress -b v6.4 https://github.com/torvalds/linux.git linux
    git clone --depth=1 https://github.com/kalous12/rockchip-kernel.git linux
    # cp ../packages/linux/config/* linux/arch/arm64/configs
    # cp ../packages/linux/dtc/* linux/arch/arm64/boot/dts/rockchip
fi

echo 1 > linux/.version
cd linux

# Compile kernel into a deb package
# make rk3568_lubancat2_defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- 
make lbc2_defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- 
make bindeb-pkg ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j32 KERNELRELEASE=6.4 KDEB_PKGVERSION=1

for file in ../linux-image*dbg*.deb ../linux-libc* ; do
    if [[ -f ${file} ]] ; then 
        rm ${file}
        echo "remove unused dir"
    fi
done 

rm -f ../*.buildinfo ../*.changes
