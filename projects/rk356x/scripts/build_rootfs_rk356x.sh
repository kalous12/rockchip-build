function build_rootfs_hook__build_rk356x() {
    echo "rk356x build start"
    cp ../projects/${BOARD_SOC}/overlay/usr/lib/systemd/system/gpu-governor-performance.service ${chroot_dir}/usr/lib/systemd/system/
    chroot ${chroot_dir} /bin/bash -c "systemctl enable gpu-governor-performance"
    echo "rk356x build finish"
}