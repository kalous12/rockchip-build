#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cleanup_loopdev() {
    local loop="$1"

    sync --file-system
    sync

    sleep 1

    if [ -b "${loop}" ]; then
        for part in "${loop}"p*; do
            if mnt=$(findmnt -n -o target -S "$part"); then
                umount "${mnt}"
            fi
        done
        losetup -d "${loop}"
    fi
}

wait_loopdev() {
    local loop="$1"
    local seconds="$2"

    until test $((seconds--)) -eq 0 -o -b "${loop}"; do sleep 1; done

    ((++seconds))

    ls -l "${loop}" &> /dev/null
}

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 filename.rootfs.tar"
    exit 1
fi

rootfs="$(readlink -f "$1")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p images build && cd build
BOARD=lubancat2
VENDOR=lubancat2

if [[ -z ${BOARD} ]]; then
    echo "Error: BOARD is not set"
    exit 1
fi

if [[ -z ${VENDOR} ]]; then
    echo "Error: VENDOR is not set"
    exit 1
fi

if [[ "${BOARD}" == lubancat2 ]]; then
    DEVICE_TREE=rk3568-lubancat-2.dtb
    OVERLAY_PREFIX=
fi

overlay_dir=../overlay

loader_dir=loader

boot_dir=boot
boot_img=boot.img
boot_size=256
boot_uuid=$(uuidgen | head -c8)

rootfs_dir=rootfs
rootfs_img=rootfs.img
root_uuid=$(uuidgen)

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

# Mount partitions
mkdir -p ${rootfs_dir} ${boot_dir} ${loader_dir}

# Copy the rootfs to rootfs partition
tar -xpf "${rootfs}" -C ${rootfs_dir}

# Set boot args for the splash screen
# [ -z "${img##*desktop*}" ] && bootargs="quiet splash plymouth.ignore-serial-consoles" || bootargs=""

# Uboot script
cat > ${boot_dir}/boot.cmd << 'EOF'
# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

setenv load_addr "0x9000000"
setenv overlay_error "false"

echo "Boot script loaded from ${devtype} ${devnum}"

if test -e ${devtype} ${devnum}:${distro_bootpart} /uEnv.txt; then
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /uEnv.txt
	env import -t ${load_addr} ${filesize}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
fdt addr ${fdt_addr_r} && fdt resize 0x10000

for overlay_file in ${overlays}; do
    if load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/${overlay_prefix}-${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/${overlay_prefix}-${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    elif load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    elif load ${devtype} ${devnum}:${distro_bootpart} ${fdtoverlay_addr_r} /dtbs/overlays/rk3588-${overlay_file}.dtbo; then
        echo "Applying device tree overlay: /dtbs/overlays/rk3588-${overlay_file}.dtbo"
        fdt apply ${fdtoverlay_addr_r} || setenv overlay_error "true"
    fi
done
if test "${overlay_error}" = "true"; then
    echo "Error applying device tree overlays, restoring original device tree"
    load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
fi

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /vmlinuz-${uname_r}
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img-${uname_r}

booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
EOF
mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d ${boot_dir}/boot.cmd ${boot_dir}/boot.scr

# Uboot env
cat > ${boot_dir}/uEnv.txt << EOF
uname_r=6.4.0
bootargs=root=UUID=${root_uuid} rootfstype=ext4 rootwait rw console=ttyS2,1500000 
fdtfile=${DEVICE_TREE}
overlay_prefix=${OVERLAY_PREFIX}
overlays=
kernel_comp_addr_r=0x19000000
kernel_comp_size=0x04000000
EOF

# Copy kernel and initrd to boot partition
cp ${rootfs_dir}/boot/initrd.img-6.4.0 ${boot_dir}
cp ${rootfs_dir}/boot/vmlinuz-6.4.0 ${boot_dir}

# Copy device trees to boot partition
mv ${rootfs_dir}/boot/firmware/* ${boot_dir}

# Create fstab entries
boot_uuid_fstab="${boot_uuid:0:4}-${boot_uuid:4:4}"
cat > ${rootfs_dir}/etc/fstab << EOF
# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>
UUID=${boot_uuid_fstab^^} /boot vfat    defaults    0       2
UUID=${root_uuid,,} /              ext4    defaults    0       1
EOF

# Copy u-boot fireware to loader_dir
cp -rfp ${rootfs_dir}/usr/lib/u-boot-"${VENDOR}"/* "${loader_dir}"

#create boot and rootfs dir to mount img 
mkdir -p ${mount_point}/{system-boot,writable} 


echo "creat boot.img"
# creat boot.img
truncate -s ${boot_size}M ${boot_img}
mkfs.vfat -i "${boot_uuid}" -F16 -n BOOT "${boot_img}"
mount ${boot_img} ${mount_point}/system-boot
cp -rfp ${boot_dir}/* ${mount_point}/system-boot
umount ${boot_img}

echo "creat rootfs.img"
# creat rootfs.img
truncate -s 8192M ${rootfs_img}
mkfs.ext4 -U "${root_uuid}" -L ROOTFS "${rootfs_img}"
mount ${rootfs_img} ${mount_point}/writable
cp -rfp ${rootfs_dir}/* ${mount_point}/writable
umount ${rootfs_img}

echo "resize rootfs.img"
# resize rootfs.img
e2fsck -p -f "${rootfs_img}"
resize2fs -M "${rootfs_img}"

# Create an empty disk image
echo "Create an empty disk image"
img="../images/$(basename "${rootfs}" .rootfs.tar).img"
size=$(( $(wc -c < boot.img) + $(wc -c < rootfs.img) + 32768 * 512 ))
size_m=$(( size / 1024 / 1024 + 10 ))
truncate -s "${size_m}M" "${img}"
echo "image large is $size_m"

# Create loop device for disk image
echo "Create loop device for disk image"
loop="$(losetup -f)"
losetup "${loop}" "${img}"
disk="${loop}"

# Cleanup loopdev on early exit
echo "Cleanup loopdev on early exit"
trap 'cleanup_loopdev ${loop}' EXIT

# Setup partition table
echo "Setup partition table"
dd if=/dev/zero of="${disk}" count=4096 bs=512
parted --script "${disk}" \
mklabel gpt \
mkpart primary fat16 16MiB 272MiB \
mkpart primary ext4 272MiB 100%

set +e

# Create partitions
fdisk "${disk}" << EOF
t
1
BC13C2FF-59E6-4262-A352-B275FD6F7172
t
2
0FC63DAF-8483-4772-8E79-3D69D8477DE4
w
EOF

set -eE

partprobe "${disk}"

partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

sleep 1

wait_loopdev "${disk}${partition_char}2" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

wait_loopdev "${disk}${partition_char}1" 60 || {
    echo "Failure to create ${disk}${partition_char}1 in time"
    exit 1
}

sleep 1

# Write bootloader to disk image
dd if=${loader_dir}/idbloader.img of="${loop}" seek=64 conv=notrunc
dd if=${loader_dir}/u-boot.itb of="${loop}" seek=16384 conv=notrunc

dd if=${boot_img} of=${disk}${partition_char}1 bs=1M
dd if=${rootfs_img} of=${disk}${partition_char}2 bs=1M

sync --file-system
sync

# Remove loop device
losetup -d "${loop}"

# Exit trap is no longer needed
trap '' EXIT

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -3 --force --keep --quiet --threads=0 "${img}"
mv ${boot_img} ../images
mv ${rootfs_img} ../images
rm -r ${rootfs_dir} ${boot_dir} ${loader_dir}
cd ../images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
