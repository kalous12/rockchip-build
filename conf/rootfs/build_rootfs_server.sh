# shellcheck shell=bash

function build_rootfs_hook__build_server() {

# Install packages

cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Download and install generic packages
apt-get -y install dmidecode mtd-tools i2c-tools u-boot-tools inetutils-ping \
bash-completion man-db manpages nano gnupg initramfs-tools vim \
dosfstools mtools parted ntfs-3g zip atop network-manager netplan.io file \
p7zip-full htop iotop pciutils lshw lsof exfat-fuse hwinfo firmware-realtek \
net-tools wireless-tools openssh-client openssh-server ifupdown bzip2 \
pigz wget curl lm-sensors gdisk usb-modeswitch usb-modeswitch-data make \
gcc libc6-dev bison libssl-dev flex usbutils fake-hwclock rfkill firmware-iwlwifi \
fdisk iperf3 dialog mmc-utils ntp rsyslog neofetch gdebi alsa-utils pulseaudio\

EOF

    # DNS
    echo "nameserver 8.8.8.8" > "${chroot_dir}/etc/resolv.conf"

    # Networking interfaces
    cp ${overlay_dir}/etc/NetworkManager/NetworkManager.conf ${chroot_dir}/etc/NetworkManager/NetworkManager.conf
    cp ${overlay_dir}/etc/NetworkManager/conf.d/10-globally-managed-devices.conf ${chroot_dir}/etc/NetworkManager/conf.d/10-globally-managed-devices.conf
    cp ${overlay_dir}/etc/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf ${chroot_dir}/etc/NetworkManager/conf.d/10-override-wifi-random-mac-disable.conf
    cp ${overlay_dir}/etc/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf ${chroot_dir}/etc/NetworkManager/conf.d/20-override-wifi-powersave-disable.conf

    # help to fix wifi
    cp ${overlay_dir}/etc/udev/rules.d/80-net-setup-link.rules ${chroot_dir}/etc/udev/rules.d/

    # Expand root filesystem on first boot
    mkdir -p ${chroot_dir}/usr/lib/scripts
    cp ${overlay_dir}/usr/lib/scripts/resize-filesystem.sh ${chroot_dir}/usr/lib/scripts/resize-filesystem.sh
    cp ${overlay_dir}/usr/lib/systemd/system/resize-filesystem.service ${chroot_dir}/usr/lib/systemd/system/resize-filesystem.service
    chroot ${chroot_dir} /bin/bash -c "systemctl enable resize-filesystem"

    # Set cpu governor to performance
    cp ${overlay_dir}/usr/lib/systemd/system/cpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/cpu-governor-performance.service
    chroot ${chroot_dir} /bin/bash -c "systemctl enable cpu-governor-performance"

    # Set term for serial tty
    mkdir -p ${chroot_dir}/lib/systemd/system/serial-getty@.service.d
    cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service.d/10-term.conf

    # auto login
    cp ${overlay_dir}/usr/lib/systemd/system/serial-getty@.service ${chroot_dir}/usr/lib/systemd/system/serial-getty@.service

    # Use gzip compression for the initrd
    cp ${overlay_dir}/etc/initramfs-tools/conf.d/compression.conf ${chroot_dir}/etc/initramfs-tools/conf.d/compression.conf

    # suitable for ax210
    rm ${chroot_dir}/usr/lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm

    # Do not create bak files for flash-kernel
    echo "NO_CREATE_DOT_BAK_FILES=true" >> ${chroot_dir}/etc/environment

    # Create swapfile on boot
    mkdir -p "${chroot_dir}/usr/lib/systemd/system/swap.target.wants/"
    (
        echo "[Unit]"
        echo "Description=Create the default swapfile"
        echo "DefaultDependencies=no"
        echo "Requires=muti-users.target"
        echo "After=muti-users.target"
        echo "Before=swapfile.swap"
        echo "ConditionPathExists=!/swapfile"
        echo ""
        echo "[Service]"
        echo "Type=oneshot"
        echo "ExecStartPre=fallocate -l 512MiB /swapfile"
        echo "ExecStartPre=chmod 600 /swapfile"
        echo "ExecStart=mkswap /swapfile"
        echo ""
        echo "[Install]"
        echo "WantedBy=swap.target"
    ) > "${chroot_dir}/usr/lib/systemd/system/mkswap.service"
    chroot "${chroot_dir}" /bin/bash -c "ln -s ../mkswap.service /usr/lib/systemd/system/swap.target.wants/"

    # Swapfile service
    (
        echo "[Unit]"
        echo "Description=The default swapfile"
        echo ""
        echo "[Swap]"
        echo "What=/swapfile"
    ) > "${chroot_dir}/usr/lib/systemd/system/swapfile.swap"
    chroot "${chroot_dir}" /bin/bash -c "ln -s ../swapfile.swap /usr/lib/systemd/system/swap.target.wants/"


cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

# Download and install generic packages
apt-get -y install libavcodec-dev libavfilter-dev libavutil-dev \
libswresample-dev ffmpeg libavdevice59 libavformat59 libpostproc56 \
libswscale6 ffmpeg-doc libavdevice-dev libavformat-dev libpostproc-dev \
libswscale-dev libavcodec59 libavfilter8 libavutil57 libswresample4 \
libsrt-openssl-dev libssh-dev pulseaudio alsa-tools alsa-utils

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

    return 0
}


