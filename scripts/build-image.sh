#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 filename.image.tar.gz"
    exit 1
fi

rootfs="$(readlink -f "$1")"
if [[ "$(basename "${rootfs}")" != *".image.tar.gz" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p images build && cd build

img="../images/$(basename "${rootfs}" .image.tar.gz).img"

overlay_dir=../overlay

loader_dir=loader

boot_img=boot.img
boot_size=256
boot_uuid=$(uuidgen | head -c8)

rootfs_img=rootfs.img
root_uuid=$(uuidgen)

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

if [[ -d ${loader_dir} ]] ; then 
    rm -r ${loader_dir}
    echo "remove unused dir"
fi

#create boot and rootfs dir to mount img 
mkdir -p ${loader_dir} ${mount_point}/{system-boot,writable} 

echo "creat boot.img"
# creat boot.img
truncate -s ${boot_size}M ${boot_img}
mkfs.vfat -i "${boot_uuid}" -F16 -n BOOT "${boot_img}"
mount ${boot_img} ${mount_point}/system-boot

echo "creat rootfs.img"
# creat rootfs.img
truncate -s 12192M ${rootfs_img}
mkfs.ext4 -U "${root_uuid}" -L ROOTFS "${rootfs_img}"
mount ${rootfs_img} ${mount_point}/writable

rootfs_dir=${mount_point}/writable
boot_dir=${mount_point}/system-boot

# Copy the rootfs to rootfs partition
tar -I pigz -xf "${rootfs}" -C ${rootfs_dir}

# Uboot script
cp ../packages/boot/boot.cmd ${boot_dir}/
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${boot_dir}/boot.cmd ${boot_dir}/boot.scr

cp ../packages/boot/lubancat.cmd ${boot_dir}/
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${boot_dir}/lubancat.cmd ${boot_dir}/lubancat.scr

if [ "${UBOOT_FLAG}" == "lubancat" ];then
    touch ${boot_dir}/lubancat
fi

# Uboot env
cat > ${boot_dir}/uEnv.txt << EOF
uname_r=5.10.160-rockchip
bootargs=root=UUID=${root_uuid} rootfstype=ext4 rootwait rw console=ttyS2,1500000 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 systemd.unified_cgroup_hierarchy=0
fdtfile=${RK_KERNEL_DTB}
overlay_prefix=${OVERLAY_PREFIX}
overlays=
EOF

# Copy kernel and initrd to boot partition
cp ${rootfs_dir}/boot/initrd.img-5.10.160* ${boot_dir}
cp ${rootfs_dir}/boot/vmlinuz-5.10.160* ${boot_dir}

# copy rk-kernel.dtb
mv ${rootfs_dir}/boot/core/* ${boot_dir}
if [ "$BOARD_SOC" == "rk356x" ];then
    if [ -f "${boot_dir}/dtbs/${RK_KERNEL_DTB}" ];then
        cp ${boot_dir}/dtbs/${RK_KERNEL_DTB} ${boot_dir}/rk-kernel.dtb
    else
        cp ${boot_dir}/dtbs/rk3568-evb1-ddr4-v10-linux.dtb  ${boot_dir}/rk-kernel.dtb
    fi
fi

# Create fstab entries
boot_uuid_fstab="${boot_uuid:0:4}-${boot_uuid:4:4}"
cat > ${rootfs_dir}/etc/fstab << EOF
# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>
UUID=${boot_uuid_fstab^^} /boot/core vfat    defaults    0       2
UUID=${root_uuid,,} /              ext4    defaults    0       1
EOF

# Copy u-boot fireware to loader_dir
cp -rfp ${rootfs_dir}/usr/lib/u-boot/* "${loader_dir}"

# tar czf rootfs.tar.gz ${rootfs_dir}

# umount 
umount ${boot_img}
umount ${rootfs_img}

echo "resize rootfs.img"
# resize rootfs.img
e2fsck -p -f "${rootfs_img}"
resize2fs -M "${rootfs_img}"

# check tools
if [[ ! $(which genimage) ]] ; then 
    echo "You need to install genimage"
    exit 0
fi

mv ${boot_img} ${loader_dir}
mv ${rootfs_img} ${loader_dir}

genimage --inputpath ${loader_dir} --outputpath ../images --config ../conf/image/genimage.cfg
rm -r tmp
mv ../images/sdcard.img ${img}

# Exit trap is no longer needed
trap '' EXIT

# echo -e "\nCompressing $(basename "${img}.xz")\n"
# xz -3 --force --keep --quiet --threads=0 "${img}"
# # rm ${boot_img}
# # rm ${rootfs_img} 
# # rm -r ${rootfs_dir} ${boot_dir} ${loader_dir}
# cd ../images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
# rm ${img}