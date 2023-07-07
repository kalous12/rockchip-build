# rockchip-build
this is build for rockchip soc.

Now it can build for rk3568

# build image
I am not ready for this. there has some issues for me.
 
## build u-boot
Now it can use mainline uboot to start your board.

```bash
./scripts/build-uboot.sh
```
what can you do when you got the result 

To write an image that boots from a SD card (assumed to be /dev/sda):

```bash
sudo dd if=u-boot-rockchip.bin of=/dev/sda seek=64
sync
```

or you can do like this

```bash
UBOOT_FIT_IMAGE=/dev/sda
dd if=idbloader.img of="${UBOOT_FIT_IMAGE}" seek=64 conv=fsync,notrunc
dd if=u-boot.itb of="${UBOOT_FIT_IMAGE}" seek=16384 conv=fsync,notrunc
sync
```

**u-boot-evb-rk3568_2023.04_arm64.deb** is a deb that you can ota your uboot.

## build kernel
I am not ready for this. 
Please wait for that.
## build rootfs
I am not ready for this. 
Please wait for that.







