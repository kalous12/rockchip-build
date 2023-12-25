#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [[ -f debian12-${ROOTFS_TYPE}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

if [[ ! -f debian12-server-arm64.rootfs.tar.xz ]]; then
    ./scripts/build-rootfs-server.sh
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

chroot_dir=rootfs
overlay_dir=../overlay

mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

apt-get -y install gnome mpv chromium mesa-utils wayland-protocols 

# install gstream
apt-get -y install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl \
gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio gstreamer1.0-plugins-base-apps

EOF

cat << EOF | chroot ${chroot_dir} /bin/bash

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean

EOF

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../debian12-desktop-arm64.rootfs.tar.xz . && cd ..
