#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build

if [[ $1 = "-f" ]]; then
    echo "rebuild"
    if [ -d linux-rockchip ]; then
        rm -r linux-rockchip
    fi
fi


if [ ! -d linux-rockchip ]; then
    git clone --depth=1 --progress -b linux-5.10-gen-rkr6 https://github.com/Joshua-Riek/linux-rockchip.git linux-rockchip
    if [ -f packages/linux/patches/series ] ;then
        for i in `cat packages/linux/patches/series`;do  
            echo "patch -d linux-rockchip -p1 < packages/linux/patches/$i";
            patch -d linux-rockchip -p1 < packages/linux/patches/"$i";
        done
    fi
fi

cd linux-rockchip
# Compile kernel into a deb package
dpkg-buildpackage -a "$(cat debian/arch)" -d -b -nc -uc
rm -f ../*.buildinfo ../*.changes
cd ../
mv *.deb build/