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
    for file in linux-{headers,image}-5.10.160*.deb; do
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

    type=server

    echo "build server img"
    # Clean chroot dir and make sure folder is not mounted
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true
    rm -rf ${chroot_dir}
    mkdir -p ${chroot_dir}

    tar -xpJf debian12-${type}-arm64.rootfs.tar.xz -C ${chroot_dir}

    echo "Mount the temporary API filesystems"
    # Mount the temporary API filesystems
    mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
    mount -t proc /proc ${chroot_dir}/proc
    mount -t sysfs /sys ${chroot_dir}/sys
    mount -o bind /dev ${chroot_dir}/dev
    mount -o bind /dev/pts ${chroot_dir}/dev/pts

    echo "Install the kernel"
    # Install the kernel
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    else
        cp linux-{headers,image}-5.10.160-rockchip_*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/linux-{headers,image}-5.10.160-rockchip*.deb && rm -rf /tmp/*"
        chroot ${chroot_dir} /bin/bash -c "apt-mark hold linux-image-5.10.160-rockchip linux-headers-5.10.160-rockchip"
    fi

    echo "Generate kernel module dependencies"
    # Generate kernel module dependencies
    chroot ${chroot_dir} /bin/bash -c "depmod -a 5.10.160-rockchip"

    echo "Copy device trees"
    # Copy device trees and overlays
    mkdir -p ${chroot_dir}/boot/core/dtbs/overlays
    cp ${chroot_dir}/usr/lib/linux-image-*/rockchip/*.dtb ${chroot_dir}/boot/core/dtbs
    cp ${chroot_dir}/usr/lib/linux-image-*/rockchip/rk3568-lubancat-2.dtb ${chroot_dir}/boot/core/rk-kernel.dtb
    # cp ${chroot_dir}/usr/lib/linux-image-5.10.160/rockchip/overlay/*.dtbo ${chroot_dir}/boot/core/dtbs/overlays

    echo "Install the bootloader"
    # Install the bootloader
    if [[ ${LAUNCHPAD}  == "Y" ]]; then
        chroot ${chroot_dir} /bin/bash -c "apt-get -y install u-boot-${VENDOR}"
    else
        cp u-boot-*.deb ${chroot_dir}/tmp
        chroot ${chroot_dir} /bin/bash -c "dpkg -i /tmp/u-boot-${VENDOR}*.deb && rm -rf /tmp/*"
        # chroot ${chroot_dir} /bin/bash -c "apt-mark hold u-boot-${BOARD}"
    fi

    echo "Update initramfs"
    # Update initramfs
    if [[ ! -f ${chroot_dir}/boot/initrd.img-5.10.160-rockchip ]]; then
        chroot ${chroot_dir} /bin/bash -c "update-initramfs -u"
    else 
        echo skip
    fi

    # Umount temporary API filesystems
    umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
    umount -lf ${chroot_dir}/* 2> /dev/null || true

    echo "Tar the entire rootfs"
    # Tar the entire rootfs
    cd ${chroot_dir} && tar -cpf ../debian12-${type}-arm64-"${BOARD}".rootfs.tar . && cd ..
    rm -r ${chroot_dir}
    ../scripts/build-image.sh debian12-${type}-arm64-"${BOARD}".rootfs.tar
    rm -f debian12-${type}-arm64-"${BOARD}".rootfs.tar

