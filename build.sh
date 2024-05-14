#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

BUILD_DIR="$(dirname -- "$(readlink -f -- "$0")")"
cd ${BUILD_DIR}

usage() {
BOARD_LIST=$(ls ${BUILD_DIR}/conf/boards | grep ".conf")
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
    for i in $(ls conf/boards | grep ".conf")
    do
    count=`expr $count + 1`
    echo "$count. ${i%".conf"}"
    done
}

show_board(){
    if [ -f "conf/boards/$1.conf" ];then
        echo source conf/boards/$1.conf
    else
        echo "--- no board ---"
        echo " Please choose one to show"
        list_board
        exit 1
    fi
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


# 清空log
if [ -d build/logs ];then
    rm -r build/logs
fi

# 查看板子配置的基本信息
show_board $BOARD
sleep 0.5
echo "source boards"

set -o allexport
source conf/boards/$BOARD.conf
set +o allexport

# 引用板子的配置的环境变量
echo BOARD_NAME=${BOARD_NAME}
echo BOARD_SOC=${BOARD_SOC}
echo UBOOT_SYSTEM=${UBOOT_SYSTEM}
echo SYSTEM_TYPE=${SYSTEM_TYPE}
echo SYSTEM_HOSTHAME=${SYSTEM_HOSTHAME}
echo SYSTEM_USER=${SYSTEM_USER}
echo SYSTEM_PASSWORD=${SYSTEM_PASSWORD}

# 解析配置，将配置写到配置文件，如果发生改动构建改动部分即可

# 只更新uboot

# 只更新内核

# 只更新根文件系统

# 更新镜像


# 记录log

mkdir -p build/logs && exec > >(tee "build/logs/build-$(date +"%Y%m%d%H%M%S").log") 2>&1

# 一套流程

# uboot修复rk3568的npu问题

if [ $(ls build | grep "${UBOOT_SYSTEM}"| grep deb) ];then 
    echo "skip build uboot"
else 
    echo "build uboot ..."
    ${BUILD_DIR}/scripts/build-uboot.sh
fi

if [ $(ls build | grep "linux-image-") ];then 
    echo "skip build kernel"
else 
    echo "build kernel ..."
    ${BUILD_DIR}/scripts/build-kernel.sh
fi

# 清除上次的没有编译的文件系统

echo "build rootfs ..."
${BUILD_DIR}/scripts/build-rootfs.sh


if [ -d "${BUILD_DIR}/images" ];then
    # 清除构建出来的镜像
    rm -r ${BUILD_DIR}/images
fi

echo "build images ..."
${BUILD_DIR}/scripts/config-image.sh

exit 0