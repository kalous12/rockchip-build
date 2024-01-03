#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR



Set gpu governor to performance
cp ${overlay_dir}/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/gpu-governor-performance.service
chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"

echo finish