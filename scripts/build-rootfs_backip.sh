#!/bin/bash

ARCH="arm64"

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [ -f rootfs.tar.gz ]; then
    exit 0
fi

# These env vars can cause issues with chroot
unset TMP
unset TEMP
unset TMPDIR

TARGET_ROOTFS_DIR="rootfs"
sudo rm -rf $TARGET_ROOTFS_DIR/

if [ ! -d $TARGET_ROOTFS_DIR ] ; then
    sudo mkdir -p $TARGET_ROOTFS_DIR

    if [ ! -e 	ubuntu-base-22.04.2-base-$ARCH.tar.gz ]; then
        echo "\033[36m wget 	ubuntu-base-22.04.2-base-"$ARCH".tar.gz \033[0m"
        wget -c http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.2-base-$ARCH.tar.gz
    fi
    sudo tar -xzf ubuntu-base-22.04.2-base-$ARCH.tar.gz -C $TARGET_ROOTFS_DIR/
    sudo cp -b /etc/resolv.conf $TARGET_ROOTFS_DIR/etc/resolv.conf
    sudo cp ../packages/rootfs/sources.list $TARGET_ROOTFS_DIR/etc/apt/sources.list

	sudo cp -b /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi

finish() {
    ../scripts/ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo -e "error exit"
    exit -1
}
trap finish ERR

echo -e "\033[47;36m Change root.................... \033[0m"

../scripts/ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR/

export APT_INSTALL="apt-get install -fy --allow-downgrades"

export LC_ALL=C.UTF-8

apt-get -y update
apt-get -f -y upgrade

DEBIAN_FRONTEND=noninteractive apt install -y rsyslog sudo dialog ntp evtest acpid

\${APT_INSTALL} net-tools openssh-server ifupdown alsa-utils ntp network-manager gdb inetutils-ping libssl-dev \
    vsftpd tcpdump can-utils i2c-tools strace vim iperf3 ethtool netplan.io toilet htop pciutils usbutils curl \
    whiptail gnupg bc xinput gdisk parted gcc sox libsox-fmt-all gpiod libgpiod-dev python3-pip python3-libgpiod \
    guvcview u-boot-tools

HOST=lubancat

# Create User
useradd -G sudo -m -s /bin/bash cat
passwd cat <<IEOF
temppwd
temppwd
IEOF
gpasswd -a cat video
gpasswd -a cat audio
passwd root <<IEOF
root
root
IEOF

# allow root login
sed -i '/pam_securetty.so/s/^/# /g' /etc/pam.d/login

# hostname
echo lubancat > /etc/hostname

# set localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# workaround 90s delay
services=(NetworkManager systemd-networkd)
for service in ${services[@]}; do
  systemctl mask ${service}-wait-online.service
done

# disbale the wire/nl80211
systemctl mask wpa_supplicant-wired@
systemctl mask wpa_supplicant-nl80211@
systemctl mask wpa_supplicant@

# Make systemd less spammy

sed -i 's/#LogLevel=info/LogLevel=warning/' \
  /etc/systemd/system.conf

sed -i 's/#LogTarget=journal-or-kmsg/LogTarget=journal/' \
  /etc/systemd/system.conf

# check to make sure sudoers file has ref for the sudo group
SUDOEXISTS="$(awk '$1 == "%sudo" { print $1 }' /etc/sudoers)"
if [ -z "$SUDOEXISTS" ]; then
  # append sudo entry to sudoers
  echo "# Members of the sudo group may gain root privileges" >> /etc/sudoers
  echo "%sudo	ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

# make sure that NOPASSWD is set for %sudo
# expecially in the case that we didn't add it to /etc/sudoers
# just blow the %sudo line away and force it to be NOPASSWD
sed -i -e '
/\%sudo/ c \
%sudo    ALL=(ALL) NOPASSWD: ALL
' /etc/sudoers

apt-get clean
rm -rf /var/lib/apt/lists/*

sync

EOF

../scripts/ch-mount.sh -u $TARGET_ROOTFS_DIR

DATE=$(date +%Y%m%d)
echo -e "\033[47;36m Run tar pack ${TARGET_ROOTFS_DIR}.tar.gz \033[0m"
# sudo tar zcf ${TARGET_ROOTFS_DIR}.tar.gz $TARGET_ROOTFS_DIR
mkdir host
cp -rfp ${TARGET_ROOTFS_DIR}/* host

cd host && tar zcf ../${TARGET_ROOTFS_DIR}.tar.gz . && cd ..
# sudo rm $TARGET_ROOTFS_DIR -r

echo -e "\033[47;36m normal exit \033[0m"
