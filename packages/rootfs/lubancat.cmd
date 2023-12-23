# This is a boot script for U-Boot
#
# Recompile with:
# mkimage -A arm64 -O linux -T script -C none -n "Boot Script" -d lubancat.cmd lubancat.scr

# get adc channel 2
adc_read 2

# get adc channel 3
adc_read 3

echo "adc channel 2 index is ${adc_index_2}"
echo "adc channel 3 index is ${adc_index_3}"

if test "${board}" = "evb_rk3588" ;then
    if test "${adc_index_2}" = "1" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat4"
        echo "device tree is rk3588s-lubancat-4.dtb"
        setenv board_name "lubancat-4"
        setenv board_dtb "rk3588s-lubancat-4.dtb"
    else 
        echo "board is not lubancat"
        setenv is_not_lubancat "yes"
    fi

elif test "${board}" = "evb_rk3568" ;then
    if test "${adc_index_2}" = "0" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat1"
        echo "device tree is rk3566-lubancat-1.dtb"
        setenv board_name "lubancat-1"
        setenv board_dtb "rk3566-lubancat-1.dtb"

    elif test "${adc_index_2}" = "0" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat1f"
        echo "device tree is rk3566-lubancat-1io.dtb"
        setenv board_name "lubancat-1f"
        setenv board_dtb "rk3566-lubancat-1io.dtb"

    elif test "${adc_index_2}" = "0" && test "${adc_index_3}" = "2" ;then
        echo "board name is lubancat1b"
        echo "device tree is rk3566-lubancat-1io.dtb"
        setenv board_name "lubancat-1b"
        setenv board_dtb "rk3566-lubancat-1io.dtb"

    elif test "${adc_index_2}" = "1" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat1n"
        echo "device tree is rk3566-lubancat-1n.dtb"
        setenv board_name "lubancat-1n"
        setenv board_dtb "rk3566-lubancat-1n.dtb"

    elif test "${adc_index_2}" = "1" && test "${adc_index_3}" = "2" ;then
        echo "board name is lubancat2bi"
        echo "device tree is rk3568-lubancat-2io.dtb"
        setenv board_name "lubancat-2bi"
        setenv board_dtb "rk3568-lubancat-2io.dtb"

    elif test "${adc_index_2}" = "2" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat0n"
        echo "device tree is rk3566-lubancat-0n.dtb"
        setenv board_name "lubancat-0n"
        setenv board_dtb "rk3566-lubancat-0n.dtb"

    elif test "${adc_index_2}" = "2" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat1h"
        echo "device tree is rk3566-lubancat-1h.dtb"
        setenv board_name "lubancat-1h"
        setenv board_dtb "rk3566-lubancat-1h.dtb"

    elif test "${adc_index_2}" = "3" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat0w"
        echo "device tree is rk3566-lubancat-0w.dtb"
        setenv board_name "lubancat-0w"
        setenv board_dtb "rk3566-lubancat-0w.dtb"

    elif test "${adc_index_2}" = "4" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat2"
        echo "device tree is rk3568-lubancat-2.dtb"
        setenv board_name "lubancat-2"
        setenv board_dtb "rk3568-lubancat-2.dtb"

    elif test "${adc_index_2}" = "4" && test "${adc_index_3}" = "2" ;then
        echo "board name is lubancat2-v1"
        echo "device tree is rk3568-lubancat-2-v1.dtb"
        setenv board_name "lubancat-2-v1"
        setenv board_dtb "rk3568-lubancat-2-v1.dtb"

    elif test "${adc_index_2}" = "4" && test "${adc_index_3}" = "3" ;then
        echo "board name is lubancat2-v2"
        echo "device tree is rk3568-lubancat-2-v2.dtb"
        setenv board_name "lubancat2-v2"
        setenv board_dtb "rk3568-lubancat-2-v2.dtb"

    elif test "${adc_index_2}" = "5" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat2n"
        echo "device tree is rk3568-lubancat-2n.dtb"
        setenv board_name "lubancat-2n"
        setenv board_dtb "rk3568-lubancat-2n.dtb"

    elif test "${adc_index_2}" = "6" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat2n"
        echo "device tree is rk3568-lubancat-2n.dtb"
        setenv board_name "lubancat-2n"
        setenv board_dtb "rk3568-lubancat-2n.dtb"

    elif test "${adc_index_2}" = "5" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat2n-v1"
        echo "device tree is rk3568-lubancat-2n-v1.dtb"
        setenv board_name "lubancat-2n-v1"
        setenv board_dtb "rk3568-lubancat-2n-v1.dtb"

    elif test "${adc_index_2}" = "6" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat2h"
        echo "device tree is rk3568-lubancat-2h.dtb"
        setenv board_name "lubancat-2h"
        setenv board_dtb "rk3568-lubancat-2h.dtb"

    elif test "${adc_index_2}" = "7" && test "${adc_index_3}" = "0" ;then
        echo "board name is lubancat2f"
        echo "device tree is rk3568-lubancat-2io.dtb"
        setenv board_name "lubancat-2f"
        setenv board_dtb "rk3568-lubancat-2io.dtb"

    elif test "${adc_index_2}" = "7" && test "${adc_index_3}" = "1" ;then
        echo "board name is lubancat2b"
        echo "device tree is rk3568-lubancat-io.dtb"
        setenv board_name "lubancat2b"
        setenv board_dtb "rk3568-lubancat-io.dtb"
    else 
        echo "board is not lubancat"
        setenv is_not_lubancat "yes"
    fi
else
    echo "board is not lubancat"
    setenv is_not_lubancat "yes"
fi


