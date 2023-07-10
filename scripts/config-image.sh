#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [[ ${LAUNCHPAD} != "Y" ]]; then
    for file in linux-{headers,image}-*.deb; do
        if [ ! -e "$file" ]; then
            echo "Error: missing kernel debs, please run build-kernel.sh"
            exit 1
        fi
    done
    for file in u-boot-${VENDOR}*.deb; do
        if [ ! -e "$file" ]; then
            echo "Error: missing u-boot deb, please run build-u-boot.sh"
            exit 1
        fi
    done
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
chroot_dir=rootfs
overlay_dir=../overlay

for type in server do

    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true
    rm -rf ${chroot_dir}
    mkdir -p ${chroot_dir}

    tar -xpJf ubuntu-22.04.2-preinstalled-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts

    # Install the kernel
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    else
        cp linux-{headers,image}-*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/linux-{headers,image}-*.deb && rm -rf /tmp/*"
        # chroot ${chroot_dir} /bin/bash -c "apt-mark hold linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    fi

    # Generate kernel module dependencies
    chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"

    # Copy device trees and overlays
    mkdir -p ${chroot_dir}/boot/firmware/dtbs/overlays
    # cp ${chroot_dir}/usr/lib/linux-image-5.10.160-rockchip/rockchip/*.dtb ${chroot_dir}/boot/firmware/dtbs
    # cp ${chroot_dir}/usr/lib/linux-image-5.10.160-rockchip/rockchip/overlay/*.dtbo ${chroot_dir}/boot/firmware/dtbs/overlays

    # Install the bootloader
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install u-boot-${BOARD}-rk3588"
    else
        cp u-boot-*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/u-boot-*.deb && rm -rf /tmp/*"
        # chroot ${chroot_dir} /bin/bash -c "apt-mark hold u-boot-${BOARD}-rk3588"
    fi

    # Update initramfs
    chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"

    # Umount temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    # Tar the entire rootfs
    cd ${chroot_dir} && tar -cpf ../ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar . && cd ..
    ../scripts/build-image.sh ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f ubuntu-22.04.2-preinstalled-${type}-arm64-"${BOARD}".rootfs.tar
done
