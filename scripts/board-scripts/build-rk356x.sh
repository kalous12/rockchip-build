#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ../../
mkdir -p build && cd build

chroot_dir=rootfs
overlay_dir=../overlay
overlay_board_dir=../overlay_board/${OVERLAY_ROOTFS}

# Set gpu governor to performance
cp ${overlay_board_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/
chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

echo finish