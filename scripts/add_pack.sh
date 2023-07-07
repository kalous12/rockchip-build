#!/bin/bash -e

TARGET_ROOTFS_DIR="/root/rootfs"

finish() {
    ./ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo -e "error exit"
    exit -1
}

trap finish ERR

./ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR/
export APT_INSTALL="apt-get install -fy --allow-downgrades"
export LC_ALL=C.UTF-8

#\${APT_INSTALL} libc6-dev
apt remove -y libc6

sync
EOF

./ch-mount.sh -u $TARGET_ROOTFS_DIR
echo -e "\033[47;36m normal exit \033[0m"
