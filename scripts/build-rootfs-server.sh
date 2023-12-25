#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -f debian12-${ROOTFS_TYPE}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

# Prevent dpkg interactive dialogues
export DEBIAN_FRONTEND=noninteractive

# Debootstrap options
arch=arm64
release=bookworm
version=12
mirror=http://mirrors.ustc.edu.cn/debian
chroot_dir=rootfs
overlay_dir=../overlay

# Clean chroot dir and make sure folder is not mounted
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true
rm -rf ${chroot_dir}

# Install the base system into a directory 
# debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}

if [[ ! -f debian12-base-${version}-base-${arch}.tar.gz ]];then
  mkdir -p ${chroot_dir}
  debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}
	tar -czf debian12-base-${version}-base-${arch}.tar.gz -C ${chroot_dir} .
  rm -r ${chroot_dir}
fi

mkdir -p ${chroot_dir}
tar -xzf debian12-base-${version}-base-${arch}.tar.gz -C ${chroot_dir}
cp -b /etc/resolv.conf ${chroot_dir}/etc/resolv.conf

# Default adduser config
# cp ${overlay_dir}/etc/adduser.conf ${chroot_dir}/etc/adduser.conf

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF

deb ${mirror} stable main contrib non-free non-free-firmware
# deb-src ${mirror} stable main contrib non-free non-free-firmware
deb ${mirror} stable-updates main contrib non-free non-free-firmware
# deb-src ${mirror} stable-updates main contrib non-free non-free-firmware

deb ${mirror} stable-proposed-updates main contrib non-free non-free-firmware
# deb-src ${mirror} stable-proposed-updates main contrib non-free non-free-firmware

EOF

# Mount the temporary API filesystems
mkdir -p ${chroot_dir}/{proc,sys,run,dev,dev/pts}
mount -t proc /proc ${chroot_dir}/proc
mount -t sysfs /sys ${chroot_dir}/sys
mount -o bind /dev ${chroot_dir}/dev
mount -o bind /dev/pts ${chroot_dir}/dev/pts


# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Download and update installed packages
apt-get -y update && apt-get -y upgrade

# apt-get -y install locales

# # Update localisation files
# locale-gen en_US.UTF-8

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools inetutils-ping \
bash-completion man-db manpages nano gnupg initramfs-tools vim \
dosfstools mtools parted ntfs-3g zip atop network-manager netplan.io file \
p7zip-full htop iotop pciutils lshw lsof exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server ifupdown sudo bzip2 \
pigz wget curl lm-sensors gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex usbutils fake-hwclock rfkill \
fdisk iperf3 dialog mmc-utils ntp rsyslog neofetch gdebi alsa-utils pulseaudio\


# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean

EOF

# Swapfile
# cat << EOF | chroot ${chroot_dir} /bin/bash
# set -eE 
# trap 'echo Error: in $0 on line $LINENO' ERR

# dd if=/dev/zero of=/tmp/swapfile bs=1024 count=2097152
# chmod 600 /tmp/swapfile
# mkswap /tmp/swapfile
# mv /tmp/swapfile /swapfile
# EOF


# add user
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

HOST=lubancat

# Create User
useradd -G sudo -m -s /bin/bash cat
passwd cat <<IEOF
temppwd
temppwd
IEOF
gpasswd -a cat video
gpasswd -a cat audio
passwd root <<IEOF
root
root
IEOF

# allow root login
sed -i '/pam_securetty.so/s/^/# /g' /etc/pam.d/login

# hostname
echo lubancat > /etc/hostname

sed -i 's/#LogLevel=info/LogLevel=warning/' \
  /etc/systemd/system.conf

sed -i 's/#LogTarget=journal-or-kmsg/LogTarget=journal/' \
  /etc/systemd/system.conf

# check to make sure sudoers file has ref for the sudo group
SUDOEXISTS="$(awk '$1 == "%sudo" { print $1 }' /etc/sudoers)"
if [ -z "$SUDOEXISTS" ]; then
  # append sudo entry to sudoers
  echo "# Members of the sudo group may gain root privileges" >> /etc/sudoers
  echo "%sudo	ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# make sure that NOPASSWD is set for %sudo
# expecially in the case that we didn't add it to /etc/sudoers
# just blow the %sudo line away and force it to be NOPASSWD
sed -i -e '
/\%sudo/ c \
%sudo    ALL=(ALL) NOPASSWD: ALL
' /etc/sudoers

sync
EOF

# DNS
cp ${overlay_dir}/etc/resolv.conf ${chroot_dir}/etc/resolv.conf

# Networking interfaces
cp ${overlay_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf
cp ${overlay_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf ${chroot_dir}/usr/lib/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf

# Expand root filesystem on first boot
mkdir -p ${chroot_dir}/usr/lib/scripts
cp ${overlay_dir}/usr/lib/scripts/resize-filesystem.sh ${chroot_dir}/usr/lib/scripts/resize-filesystem.sh
cp ${overlay_dir}/usr/lib/systemd/system/resize-filesystem.service ${chroot_dir}/usr/lib/systemd/system/resize-filesystem.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable resize-filesystem"

# Set cpu governor to performance
cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

# Set gpu governor to performance
cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# auto login
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service

# Use gzip compression for the initrd
cp ${overlay_dir}/etc/initramfs-tools/conf.d/compression.conf ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

# Do not create bak files for flash-kernel
echo "NO_CREATE_DOT_BAK_FILES=true" >> ${chroot_dir}/etc/environment


cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Download and install generic packages
apt-get -y install libavcodec-dev libavfilter-dev libavutil-dev \
libswresample-dev ffmpeg libavdevice59 libavformat59 libpostproc56 \
libswscale6 ffmpeg-doc libavdevice-dev libavformat-dev libpostproc-dev \
libswscale-dev libavcodec59 libavfilter8 libavutil57 libswresample4

EOF

mkdir -p ${chroot_dir}/package/hardware
# install extra packages
for PACKAGE_NAME in "librga2" "librockchip-mpp1" "gstreamer-rockchip" "rknpu2" "ffmpeg"
do
  cp ../packages/hardware/${PACKAGE_NAME}*.deb ${chroot_dir}/package/hardware
  chroot ${chroot_dir} /bin/bash -c "dpkg -i /package/hardware/${PACKAGE_NAME}*.deb"
done

chroot ${chroot_dir} /bin/bash -c "apt-mark hold ffmpeg"

# rga testfiles copy to rootfs
mkdir -p ${chroot_dir}/usr/data
cp ${overlay_dir}/usr/data/* ${chroot_dir}/usr/data/

# make media run in user
cp ${overlay_dir}/etc/udev/rules.d/99-rockchip-permissions.rules ${chroot_dir}/etc/udev/rules.d/

cp ${overlay_dir}/usr/lib/firmware/mali_csffw.bin ${chroot_dir}/usr/lib/firmware

cat << EOF | chroot ${chroot_dir} /bin/bash
  apt-get -y install libsrt-openssl-dev libssh-dev
EOF

if [ "$BOARD_SOC" == "rk3588" ];then

mkdir -p ${chroot_dir}/package/gpu

cp ../packages/gpu/rk3588/* ${chroot_dir}/package/gpu

cat << EOF | chroot ${chroot_dir} /bin/bash
apt-get -y install \
libc6 libexpat1 libgcc-s1 libllvm14 libsensors5 libstdc++6 \
libdrm-dev libdrm2 zlib1g libudev1 libxshmfence1 \
libxcb1 libx11-xcb1 libxcb-dri2-0 libxcb-dri3-0 \
libxcb-present0 libxcb-randr0 libxcb-sync1 libxcb-xfixes0 \
libwayland-dev libwayland-bin libgles2 libgles-dev \
wayland-protocols libwayland-egl-backend-dev \
libx11-6 libxcb-glx0 libxcb-shm0 libxext6 libxxf86vm1 \
libwayland-egl1 libx11-dev libglx-dev libgl-dev \
libclc-14 ocl-icd-libopencl1 \
libvdpau1 libvulkan1 libegl-dev libglvnd-dev

cd /package/gpu

dpkg -i \
mali-g610-firmware_1.0.2_all.deb \
libosmesa6_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libd3dadapter9-mesa_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libegl1-mesa_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libegl1-mesa-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgl1-mesa-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libglapi-mesa_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgles2-mesa_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgles2-mesa-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgbm1_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
mesa-common-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
mesa-opencl-icd_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
mesa-va-drivers_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
mesa-vdpau-drivers_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
mesa-vulkan-drivers_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb 

dpkg -i \
libosmesa6-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libd3dadapter9-mesa-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgl1-mesa-dri_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libegl-mesa0_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libgbm-dev_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb \
libglx-mesa0_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb 

dpkg -i libgl1-mesa-glx_23.0.5-0ubuntu1~panfork~git221210.120202c6757~j3_arm64.deb

EOF

fi

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../debian12-server-arm64.rootfs.tar.xz . && cd ..
