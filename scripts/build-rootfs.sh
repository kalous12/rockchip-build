#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -f debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.rootfs.tar.gz ]]; then
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

if [[ ! -f debian12-base-rootfs-${arch}.tar.gz ]];then
  mkdir -p ${chroot_dir}
  debootstrap --arch ${arch} ${release} ${chroot_dir} ${mirror}
	tar -I pigz -cf debian12-base-rootfs-${arch}.tar.gz -C ${chroot_dir} .
  rm -r ${chroot_dir}
fi

mkdir -p ${chroot_dir}
tar -I pigz -xf debian12-base-rootfs-${arch}.tar.gz -C ${chroot_dir}
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


trap 'echo Error: in $0 on line $LINENO ; \
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true ; \
umount -lf ${chroot_dir}/* 2> /dev/null || true' ERR

# Download and update packages
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Download and update installed packages
apt-get -y update && apt-get -y upgrade

apt-get -y install locales

# # Update localisation files
sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen 
echo "LANG=en_US.UTF-8" >> /etc/default/locale
update-locale

# Clean package cache
apt-get -y autoremove && apt-get -y clean && apt-get -y autoclean
EOF

# run script user setting 
source ../conf/rootfs/build_rootfs_user.sh
echo "build_rootfs_hook__build_user"
build_rootfs_hook__build_user

# run script server or desktop
source ../conf/rootfs/build_rootfs_${SYSTEM_TYPE}.sh
echo "build_rootfs_hook__build_${SYSTEM_TYPE}"
build_rootfs_hook__build_${SYSTEM_TYPE}

# run script platform server or desktop(eg: 356x 3588)
source ../projects/${BOARD_SOC}/scripts/build_rootfs_${BOARD_SOC}.sh
echo "build_rootfs_hook__build_${BOARD_SOC}"
build_rootfs_hook__build_${BOARD_SOC}

# run script board server or desktop (eg: 吉祥机 , lubancat)
source ../projects/${BOARD_SOC}/scripts/build_rootfs_${BOARD_SOC}_${BOARD_NAME}.sh
echo "build_rootfs_hook__build_${BOARD_SOC}_${BOARD_NAME}"
build_rootfs_hook__build_${BOARD_SOC}_${BOARD_NAME}

# Clean package cache
chroot ${chroot_dir} apt-get -y autoremove
chroot ${chroot_dir} apt-get -y clean
chroot ${chroot_dir} apt-get -y autoclean

# Umount temporary API filesystems
umount -lf ${chroot_dir}/dev/pts 2> /dev/null || true
umount -lf ${chroot_dir}/* 2> /dev/null || true

# Tar the entire rootfs
cd ${chroot_dir} && tar -I pigz -cf ../debian12-arm64-${SYSTEM_TYPE}-${BOARD_SOC}-${BOARD_NAME}.rootfs.tar.gz . && cd ..
