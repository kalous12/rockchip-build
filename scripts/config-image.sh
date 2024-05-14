#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# 查找uboot包 kernel包
# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
chroot_dir=rootfs
overlay_dir=../overlay

echo "config image"
# Clean chroot dir and make sure folder is not mounted
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true
rm -rf ${chroot_dir}
mkdir -p ${chroot_dir}

tar -I pigz -xf debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.rootfs.tar.gz -C ${chroot_dir}

echo "Mount the temporary API filesystems"
# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Download and update installed packages
chroot ${chroot_dir} apt-get -y update
chroot ${chroot_dir} apt-get -y upgrade 
chroot ${chroot_dir} apt-get -y dist-upgrade

# Install the bootloader
cp u-boot-*.deb ${chroot_dir}/tmp
chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/u-boot-*.deb && rm -rf /tmp/*"

# Install the kernel
cp linux-{headers,image}-5.10.160-rockchip_*.deb ${chroot_dir}/tmp
chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/linux-{headers,image}-5.10.160-rockchip*.deb && rm -rf /tmp/*"
chroot ${chroot_dir} /bin/bash -c "apt-mark hold linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"

# copy devicetree
mkdir -p ${chroot_dir}/boot/core/dtbs/overlays
cp ${chroot_dir}/usr/lib/linux-image-*/rockchip/*.dtb ${chroot_dir}/boot/core/dtbs

# Clean package cache
chroot ${chroot_dir} apt-get -y autoremove
chroot ${chroot_dir} apt-get -y clean
chroot ${chroot_dir} apt-get -y autoclean

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

echo "Tar the entire rootfs"
# Tar the entire rootfs
cd ${chroot_dir} && tar -I pigz -cf ../debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.image.tar.gz . && cd ..
rm -r ${chroot_dir}
../scripts/build-image.sh debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.image.tar.gz
rm -f debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.image.tar.gz

