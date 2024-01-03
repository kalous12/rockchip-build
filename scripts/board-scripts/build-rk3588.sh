#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

chroot_dir=rootfs
overlay_dir=../overlay
overlay_board_dir=../overlay_board/${OVERLAY_ROOTFS}

# Set gpu governor to performance
cp ${overlay_board_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

# Install gpu
cp ${overlay_board_dir}/usr/lib/firmware/mali_csffw.bin ${chroot_dir}/usr/lib/firmware
mkdir -p ${chroot_dir}/package/gpu
cp ${overlay_board_dir}/packages/gpu/* ${chroot_dir}/package/gpu

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

cp ${overlay_board_dir}/etc/udev/rules.d/99-rockchip-permissions.rules ${chroot_dir}/etc/udev/rules.d/

echo finish