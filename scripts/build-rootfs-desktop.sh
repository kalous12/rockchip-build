#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [ -f "debian12-desktop-arm64.rootfs.tar.gz" ]; then
    echo "no need to rebuild"
    exit 0
fi

if [ -f "debian12-server-arm64.rootfs.tar.gz" ]; then
    echo "skip build server img"
else
    echo "no server img --> rebuild"
    ../scripts/build-rootfs-server.sh
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

chroot_dir=rootfs
overlay_dir=../overlay

if [ -d ${chroot_dir} ]; then
    rm -r ${chroot_dir}
fi

mkdir -p ${chroot_dir}

tar -I pigz -xf debian12-server-arm64.rootfs.tar.gz -C ${chroot_dir}

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


cp ${overlay_dir}/gnome-setting/user ${chroot_dir}/home/cat/

cat << EOF | chroot ${chroot_dir} /bin/bash
# copy dconf to control power setting
su cat
mkdir -p /home/cat/.config/dconf/
mv /home/cat/user /home/cat/.config/dconf/
EOF

mkdir -p ${chroot_dir}/etc/chromium
cp ${overlay_dir}/etc/chromium/default ${chroot_dir}/etc/chromium

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

cd ${chroot_dir} && tar -I pigz -cf ../debian12-desktop-arm64.rootfs.tar.gz . && cd ..
