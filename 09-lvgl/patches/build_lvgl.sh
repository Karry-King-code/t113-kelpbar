#!/bin/sh
# T113 KelpBar LVGL 一键交叉编译（源码全部来自 Tina SDK 自带，无需下载）
# 用法: sh ~/build_lvgl.sh   （产物 ~/lvgl_kelpbar/lv_examples）
set -e
SDK=$HOME/T113-Tina5.0-V1.2
export PATH=$SDK/openwrt/openwrt/staging_dir/toolchain/bin:$PATH
export STAGING_DIR=$SDK/openwrt/openwrt/staging_dir/target

P=$SDK/platform/thirdparty/gui/lvgl-8
W=$HOME/lvgl_kelpbar
rm -rf $W && mkdir -p $W
cp -r $P/lvgl $P/lv_drivers $W/
cp $P/lv_examples/src/main.c $P/lv_examples/src/Makefile $P/lv_examples/src/lv_conf.h $P/lv_examples/src/lv_drv_conf.h $W/
# 本板触摸 GT9xx 在 /dev/input/event5（cat /proc/bus/input/devices 复核）
sed -i 's|/dev/input/event3|/dev/input/event5|' $W/lv_drv_conf.h

cd $W && make CC=arm-openwrt-linux-gcc -j8
echo BUILD_OK: $W/lv_examples

[exit code: 0]
