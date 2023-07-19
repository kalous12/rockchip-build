#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -f ubuntu-22.04.2-server-arm64.rootfs.tar.xz ]]; then
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
release=jammy
version=22.04.2
mirror=http://mirrors.ustc.edu.cn/ubuntu-ports/
chroot_dir=rootfs
overlay_dir=../overlay

# Clean chroot dir and make sure folder is not mounted
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true
rm -rf ${chroot_dir}
mkdir -p ${chroot_dir}

# Install the base system into a directory 
# debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}

if [[ ! -f ubuntu-base-${version}-base-${arch}.tar.gz ]];then
	wget http://cdimage.ubuntu.com/ubuntu-base/releases/${version}/release/ubuntu-base-${version}-base-${arch}.tar.gz
fi

tar -xzf ubuntu-base-${version}-base-${arch}.tar.gz -C ${chroot_dir}
cp -b /etc/resolv.conf ${chroot_dir}/etc/resolv.conf

# Use a more complete sources.list file 
cat > ${chroot_dir}/etc/apt/sources.list << EOF
deb ${mirror} ${release} main restricted universe multiverse
# deb-src ${mirror} ${release} main restricted universe multiverse

deb ${mirror} ${release}-security main restricted universe multiverse
# deb-src ${mirror} ${release}-security main restricted universe multiverse

deb ${mirror} ${release}-updates main restricted universe multiverse
# deb-src ${mirror} ${release}-updates main restricted universe multiverse

deb ${mirror} ${release}-backports main restricted universe multiverse
# deb-src ${mirror} ${release}-backports main restricted universe multiverse
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

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools inetutils-ping \
bash-completion man-db manpages nano gnupg initramfs-tools locales vim \
dosfstools mtools parted ntfs-3g zip atop network-manager netplan.io file \
p7zip-full htop iotop pciutils lshw lsof landscape-common exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server ifupdown sudo bzip2 \
pigz wget curl lm-sensors gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex flash-kernel fake-hwclock rfkill \
fdisk 

# Remove cryptsetup and needrestart
apt-get -y remove cryptsetup needrestart

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

locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

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

apt-get clean
rm -rf /var/lib/apt/lists/*

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
# cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
# chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

# Set gpu governor to performance
# cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
# chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

# Set term for serial tty
mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-22.04.2-server-arm64.rootfs.tar.xz . && cd ..