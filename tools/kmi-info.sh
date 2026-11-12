#!/usr/bin/env bash
# ============================================================================
# kmi-info.sh —— 读取手机"当前正在跑的内核"版本串，用来更新 workflow 的 env
#
# 用法:
#   ./tools/kmi-info.sh                 # 默认 127.0.0.1:15555（反向隧道）
#   ADB_SERIAL=xxx ./tools/kmi-info.sh  # 指定 adb 序列号
#   ADB=/path/to/adb ./tools/kmi-info.sh
#
# KERNEL_NAME = uname -r 去掉 "6.6.<sub>-" 前缀，直接填 workflow 的 env.KERNEL_NAME。
# ============================================================================
set -u

ADB="${ADB:-adb}"
SERIAL="${ADB_SERIAL:-127.0.0.1:15555}"

if ! command -v "$ADB" >/dev/null 2>&1; then
  echo "找不到 adb：请用 ADB=/绝对路径/adb 指定" >&2
  exit 1
fi

A="$ADB -s $SERIAL"
if ! $A get-state >/dev/null 2>&1; then
  echo "手机未连接（$SERIAL）。先确认 adb devices 能看到设备。" >&2
  exit 1
fi

get() { $A shell "$1" 2>/dev/null | tr -d '\r'; }

UNAME_R="$(get 'uname -r')"
MODEL="$(get 'getprop ro.product.model')"
NAME="$(get 'getprop ro.product.name')"
DISPLAY_ID="$(get 'getprop ro.build.display.id')"
ANDROID_REL="$(get 'getprop ro.build.version.release')"
SDK="$(get 'getprop ro.build.version.sdk')"
FP="$(get 'getprop ro.build.fingerprint')"
SLOT="$(get 'getprop ro.boot.slot_suffix')"

SUB="$(echo "$UNAME_R" | sed -n 's/^6\.6\.\([0-9]*\)-.*/\1/p')"
KNAME="$(echo "$UNAME_R" | sed -n 's/^6\.6\.[0-9]*-\(.*\)$/\1/p')"

echo "机型        : $MODEL ($NAME)"
echo "系统        : Android $ANDROID_REL (SDK $SDK) / $DISPLAY_ID"
echo "槽位        : ${SLOT:-_a}"
echo "uname -r    : $UNAME_R"
echo "fingerprint : $FP"
echo
echo "→ 填进 workflow 的三处："
echo "  env.KERNEL_NAME: '$KNAME'"
echo "  env.SUB_VERSION: '$SUB'（同时改 inputs.sub_level 默认值）"
echo "  inputs.source_branch: 与 6.6.$SUB 对应的官方分支（当前为 oneplus/mt6991_b_16.0.0_oneplus_ace5_ultra）"
echo
echo "→ 官方 vendor 模块 vermagic 参考（MODVERSIONS=y 时只比较第一个空格之后的部分）："
$A shell 'for m in /vendor/lib/modules/gps_pwr.ko /vendor/lib/modules/cfg80211.ko; do [ -f "$m" ] && echo "  $(basename $m): $(modinfo -F vermagic $m 2>/dev/null || echo 需root)"; done' 2>/dev/null | tr -d '\r'
