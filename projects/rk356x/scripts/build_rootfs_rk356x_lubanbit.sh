function build_rootfs_hook__build_rk356x_lubanbit() {
    echo "rk356x lubanbit build"
    
cat << EOF | chroot ${chroot_dir} /bin/bash
    apt -y install software-properties-common
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9C7705BF
    add-apt-repository -S "deb https://ppa.launchpadcontent.net/ippclub/dora-ssr/ubuntu jammy main"
    apt update
    apt -y install dora-ssr
EOF
}