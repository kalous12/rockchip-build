
function build_rootfs_hook__build_user() {
# add user
cat << EOF | chroot ${chroot_dir} /bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

apt-get -y install sudo

HOST=${SYSTEM_HOSTHAME}

# Create User
useradd -G sudo -m -s /bin/bash ${SYSTEM_USER}
passwd ${SYSTEM_USER} <<IEOF
${SYSTEM_PASSWORD}
${SYSTEM_PASSWORD}
IEOF
passwd root <<IEOF
root
root
IEOF

# allow root login
sed -i '/pam_securetty.so/s/^/# /g' /etc/pam.d/login

# hostname
echo "${SYSTEM_HOSTHAME}" > /etc/hostname

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

sync
EOF

# make media run in user
cp ${overlay_dir}/etc/udev/rules.d/99-rockchip-permissions.rules ${chroot_dir}/etc/udev/rules.d/

};

