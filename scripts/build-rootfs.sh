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

# Install the base system into a directory 
# debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}

if [[ ! -f ubuntu-base-${version}-base-${arch}.tar.gz ]];then
  mkdir -p ${chroot_dir}
  debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}
	tar -czf ubuntu-base-${version}-base-${arch}.tar.gz -C ${chroot_dir} .
  rm -r ${chroot_dir}
fi

mkdir -p ${chroot_dir}
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

cp ${overlay_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa ${chroot_dir}/etc/apt/preferences.d/rockchip-multimedia-ppa

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Update localisation files
locale-gen en_US.UTF-8
update-locale LANG="en_US.UTF-8"

apt-get -y update && apt-get -y install software-properties-common
add-apt-repository -y ppa:liujianfeng1994/panfork-mesa
add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia

# Download and update installed packages
apt-get -y update && apt-get -y upgrade

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools inetutils-ping \
bash-completion man-db manpages nano gnupg initramfs-tools locales vim \
dosfstools mtools parted ntfs-3g zip atop network-manager netplan.io file \
p7zip-full htop iotop pciutils lshw lsof landscape-common exfat-fuse hwinfo \
net-tools wireless-tools openssh-client openssh-server ifupdown sudo bzip2 \
pigz wget curl lm-sensors gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex usbutils fake-hwclock rfkill \
fdisk linux-firmware iperf3 dialog mmc-utils


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

#install gpus
# cat << EOF | chroot ${chroot_dir} /bin/bash
# set -eE 
# trap 'echo Error: in $0 on line $LINENO' ERR

# apt-get -y update

# # Download and update installed packages
# apt-get -y install pkg-config libwayland-bin wayland-protocols \
# pulseaudio libgbm-dev python3-mako cmake zlib1g-dev libexpat-dev \
# pkg-config libdrm-dev libwayland-dev libwayland-bin \
# wayland-protocols  libwayland-egl-backend-dev 

# # Clean package cache
# apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean

# EOF

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

# cp ../packages/mesa/g52-mesa_*.deb ${chroot_dir}/root

# cat << EOF | chroot ${chroot_dir} /bin/bash

# # dpkg -i /root/g52-mesa_*.deb

# EOF

cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Desktop packages
apt-get -y install ubuntu-desktop dbus-x11 xterm pulseaudio pavucontrol qtwayland5 \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good mpv \
gstreamer1.0-tools gstreamer1.0-rockchip1 chromium-browser mali-g610-firmware malirun \
rockchip-multimedia-config librist4 librist-dev rist-tools dvb-tools ir-keytable \
libdvbv5-0 libdvbv5-dev libdvbv5-doc libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev \
libv4l-rkmpp qv4l2 v4l-utils librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 \
rockchip-mpp-demos librga2 librga-dev libegl-mesa0 libegl1-mesa-dev libgbm-dev \
libgl1-mesa-dev libgles2-mesa-dev libglx-mesa0 mesa-common-dev mesa-vulkan-drivers \
mesa-utils libwidevinecdm libcanberra-pulse

# Remove cloud-init and landscape-common
apt-get -y purge cloud-init landscape-common

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && XZ_OPT="-3 -T0" tar -cpJf ../ubuntu-22.04.2-server-arm64.rootfs.tar.xz . && cd ..