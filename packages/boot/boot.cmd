# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d boot.cmd boot.scr

setenv load_addr "0x7900000"
setenv overlay_error "false"

echo "Boot script loaded from ${devtype} ${devnum}"
echo "start to go"


if test -e ${devtype} ${devnum}:${distro_bootpart} /uEnv.txt; then
    echo "load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /uEnv.txt"
	load ${devtype} ${devnum}:${distro_bootpart} ${load_addr} /uEnv.txt
	env import -t ${load_addr} ${filesize}
fi

if test -e ${devtype} ${devnum}:${distro_bootpart} /lubancat ;then

    setenv lubancat_script_addr 0x00550000
    load mmc 1:1 ${lubancat_script_addr} lubancat.scr
    source ${lubancat_script_addr}

    if test -e ${devtype} ${devnum}:${distro_bootpart} /dtbs/${board_dtb}; then
        echo "use autodetect"
        echo "load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${board_dtb}"
        load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${board_dtb}
        fdt addr ${fdt_addr_r} && fdt resize 0x10000
    else
        echo "load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}"
        load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
        fdt addr ${fdt_addr_r} && fdt resize 0x10000
    fi
else
    echo "load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}"
    load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} /dtbs/${fdtfile}
    fdt addr ${fdt_addr_r} && fdt resize 0x10000
fi 

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

echo "load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /vmlinuz-${uname_r}"
load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} /vmlinuz-${uname_r}

echo "load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img-${uname_r}"
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} /initrd.img-${uname_r}

echo "booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}"
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}