Good Good Study Day Day Up!

Life is a fuking movie.

nerver give up your life !!! 

# rockchip-build
this is build for rockchip soc.

Now it can build for rk3568.

you can build for embedfire-lubancat2

now you just can build ubuntu22.04 server and other is prepare to finish 
# build image
now you can do this to build image

```bash
cd rockchip-build
./build.sh --board=lubancat2
```

or to config your board

```bash
./build.sh --help
```

the img dir in ``rockchip-build/images``

----
 
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
Now it can use mainline uboot to start your board.

you can get two deb ``linux-headers-*_arm64.deb`` and ``linux-image-*_arm64.deb``

it can update your kernel when you are use it in your board 

transfer this debs to your board and do this 

```bash
# install kernel
dpkg -i linux-{headers,image}*.deb

# reboot to make it work
reboot 
```

## build rootfs

**build/log** :you can find your build log that can make you easy to debug




