#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

cd "$(dirname -- "$(readlink -f -- "$0")")"

mkdir -p build/logs
exec > >(tee "build/logs/build-$(date +"%Y%m%d%H%M%S").log") 2>&1


usage() {
BOARD_LIST=$(ls conf | grep ".conf")
BOARD_LIST_SHOW=
for i in $BOARD_LIST
do
    if [ -z "$BOARD_LIST_SHOW" ];then
        BOARD_LIST_SHOW="${i%".conf"}"
    else
        BOARD_LIST_SHOW="${BOARD_LIST_SHOW}|${i%".conf"}"
    fi
done

cat << HEREDOC
Usage: $0 --board=[$BOARD_LIST_SHOW]

Required arguments:
  -b, --board=BOARD     target board 

Optional arguments:
  -l,  --list-board      list all boards can build
  -s,  --show=BOARD      show the details of boards configure
  -h,  --help            show this help message and exit
  -c,  --clean           clean the build directory
  -v,  --verbose         increase the verbosity of the bash script
HEREDOC
}

list_board() {
    count=0
    for i in $(ls conf | grep ".conf")
    do
    count=`expr $count + 1`
    echo "$count. ${i%".conf"}"
    done
}

show_board(){
    if [ -f "conf/$1" ];then
        source conf/$1
    else
        if [ -f "conf/$1.conf" ];then
            source conf/$1.conf
        else
            echo "--- no board ---"
            echo " Please choose one to show"
            list_board
            exit 1
        fi 
    fi
    echo BOARD_NAME=$BOARD_NAME
    echo UBOOT_SYSTEM=$UBOOT_SYSTEM
}

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit 0
            ;;
        -b=*|--board=*)
            export BOARD="${i#*=}"
            shift
            ;;
        -b|--board)
            export BOARD="${2}"
            shift
            ;;
        -c|--clean)
            export CLEAN=Y
            ;;
        -l|--list-board)
            list_board
            exit 0
            ;;
        -s=*|--show=*)
            export BOARD="${i#*=}"
            show_board $BOARD
            sleep 0.5
            exit 0
            ;;
        -s|--show)
            export BOARD="${2}"
            show_board $BOARD
            sleep 0.5
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -*)
            echo "Error: unknown argument \"$i\""
            usage
            exit 1
            ;;
        *)
            ;;
    esac
done


show_board $BOARD
sleep 0.5

export VENDOR=$UBOOT_SYSTEM
export BOARD=$BOARD_NAME
export BOARD_SOC=$BOARD_SOC

export K_DEVICE_TREE=$DEVICE_TREE
export OVERLAY_PREFIX=$OVERLAY_PREFIX
export ROOTFS_TYPE=$ROOTFS_TYPE
export ROOTFS_SCRIPT=$ROOTFS_SCRIPT
export OVERLAY_ROOTFS=$OVERLAY_ROOTFS

if [ $(ls build | grep "u-boot-${VENDOR}"| grep deb) ];then 
    echo "skip build uboot"
else 
    echo "build uboot ..."
    ./scripts/build-uboot.sh -f
fi

if [ $(ls build | grep "linux-image-") ];then 
    echo "skip build kernel"
else 
    echo "build kernel ..."
    ./scripts/build-kernel.sh
fi

if [ -d "build/rootfs" ]; then
    rm -r build/rootfs
fi

if [ -d "images" ]; then
    rm -r images
fi

# build base filesystem

if [ -f "./scripts/build-rootfs-${ROOTFS_TYPE}.sh" ];then
    ./scripts/build-rootfs-${ROOTFS_TYPE}.sh
else
    echo "please choose your filesystem : desktop or server"
    exit 1
fi

./scripts/config-image.sh

exit 0
