#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build & cd build  

# kernel 脚本选项

KERNEL_TARGET=rockchip-5.10

# 选择脚本
source ../conf/kernels/"${KERNEL_TARGET}.conf"

if [ ! -d linux-rockchip ]; then
    git clone --progress -b "${KERNEL_TAG}" "${KERNEL_REPO}" "${KERNEL_CLONE_DIR}" --depth=1
    # if [ -f ../packages/linux/patches/series ] ;then
    #     for i in `cat ../packages/linux/patches/series`;do  
    #         echo "patch -d linux-rockchip -p1 < ../packages/linux/patches/$i";
    #         patch -d linux-rockchip -p1 < ../packages/linux/patches/"$i";
    #     done
    # fi
fi

cd linux-rockchip
# Compile kernel into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc
rm -f ../*.buildinfo ../*.changes
cd ../