# 一加 Ace 5 至尊版 (PLC110 / MT6991) 内核适配说明

> 目标仓库：`bocchi810/oppo_oplus_realme_sm8750`（本说明新增的文件都在这个仓库里）
> 新增文件：`.github/workflows/fastbuild_mt6991_ace5_ultra.yml`、`tools/kmi-info.sh`

---

## 0. 先看结论

| 项 | 值 |
| --- | --- |
| 机型 | 一加 Ace 5 至尊版 (PLC110 / MT6991 / 天玑 9400+) |
| 系统（实测） | Android 17 (SDK 37)，`PLC110_17.0.0.100(CN01)` |
| 内核（实测） | `6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k` |
| 官方源码 | `OnePlusOSS/android_kernel_oneplus_mt6991` @ `oneplus/mt6991_b_16.0.0_oneplus_ace5_ultra`（Makefile **6.6.118**） |
| 结论 | **“最新版本”就是 6.6.118**：官方仓库目前只有 3 个分支（b_16.0.0 ace5_ultra = 6.6.118、v_15.0.2 ace5_ultra = 6.6.89、pad_2），没有更新的分支；手机实际跑的也是 6.6.118 |

手机当前状态（`tools/kmi-info.sh` 实测）：

`~

机型        : PLC110 (PLC110)
系统        : Android 17 (SDK 37) / PLC110_17.0.0.100(CN01)
槽位        : _a
uname -r    : 6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k
fingerprint : OnePlus/PLC110/OP60EDL1:17/CP2A.260605.016/V.1f3b189_74eca2_74eca3:user/release-keys
`~

Bootloader 已解锁（`verifiedbootstate=orange`）；当前是**官方内核 + KernelSU LKM**（`lsmod` 里有 `kernelsu` 模块，`/proc/version` 显示 `kleaf@build-host`，编译时间 2026-07-22），并没有跑任何自编译内核。

---

## 1. 为什么是 6.6.118，而不是“往上再并一个版本”

1. **官方只开源到 6.6.118**。`git ls-remote` 得到的全部分支：

   `~text
   oneplus/mt6991_b_16.0.0_oneplus_ace5_ultra     ← Makefile 6.6.118（最新）
   oneplus/mt6991_v_15.0.2_ace5_ultra             ← Makefile 6.6.89
   oneplus/mt6991_b_16.0.0_pad_2                  ← 平板，不适用
   `~

2. **手机上的内核也是 6.6.118**（见上）。官方 vendor 模块（`/vendor/lib/modules` 共 381 个 `.ko`）是用这套源码 + Kleaf 编出来的。

3. **能不能并到 6.6.162（当前 6.6 LTS 最新）？不建议**。原因不是版本号，而是**符号 CRC**：
   - 本内核 `CONFIG_MODVERSIONS=y`，加载模块时逐个符号比对 CRC（`kernel/module/version.c: check_version()`）。
   - 版本串前缀反而不参与判定：`same_magic()` 在模块带 CRC 时把“第一个空格之前”的版本号**丢掉只比后面部分**（注释原文：`First part is kernel version, which we ignore if module has crcs.`）。实测官方模块 vermagic 是 `6.6.118-android15-8-o-g958f1e2e0ae5-4k`，与内核自己的 `…-g9bc34d5b0c79-…` 本来就不同，照样加载。
   - 真正的硬约束是 CRC：跨 44 个 stable 小版本，`mm/`、`net/`、`fs/` 的导出符号类型几乎必然变化，vendor 模块会直接报 `disagrees about version of symbol` 加载失败 → 相机/WiFi/基带全挂。
   - 所以“最新版本”= **官方最新源码 6.6.118**，而不是上游 LTS 6.6.162。

---

## 2. 相对 SM8750 workflow，必须改的三处

| 适配点 | 原 SM8750 workflow | 本适配（MT6991 / Ace5 至尊版） |
| --- | --- | --- |
| 源码 | `cctv18/android_kernel_common_oneplus_sm8750` @ `sm8750_b_16.0.0_oneplus_13_6.6.118` | `OnePlusOSS/android_kernel_oneplus_mt6991` @ `oneplus/mt6991_b_16.0.0_oneplus_ace5_ultra` |
| 版本串 | `android15-8-g29d86c5fc9dd-abogki428889875-4k`（一加 13 的 KMI） | `android15-8-g9bc34d5b0c79-abogki537459655-4k`（本机 `uname -r` 实测） |
| 天玑差异 | — | ① 不写 `CONFIG_BPF_STREAM_PARSER`（MTK 会导致 WiFi/蓝牙异常，见 cctv18 提交 `44557eb`）② lz4 补丁追加 `001-lz4-clearMake.patch`（MTK 的 `lib/Makefile` 布局不同）③ 内置 hybridswap 空指针守卫（本机专用 bug） |

另外两处工程性加固（不改变产物，只让失败更早暴露）：

- **源码版本自检**：拉完源码先读 `Makefile` 的 `VERSION.PATCHLEVEL.SUBLEVEL`，与 `inputs.sub_level` 不一致直接失败，避免拿错分支编出白刷的包。
- **版本串硬校验**：`make gki_defconfig` 后断言 `CONFIG_LOCALVERSION`、`CONFIG_MODVERSIONS`、`CONFIG_KSU(_SUSFS)`；`make Image` 后断言 `out/include/generated/utsrelease.h` 的 `UTS_RELEASE` 必须等于 `6.6.118-<KERNEL_NAME>`，并在 `vmlinux` 里抓到 vermagic，否则**不产出 zip**。

---

## 3. 怎么用

### 3.1 第一次：只跑预检（约 2 分钟）

Actions → `(MT6991) 一加 Ace 5 至尊版 6.6.118 OKI 内核构建` → Run workflow：

- `verify_only` = **true**
- 其余保持默认

这一步会把“拉源码 → 打全部补丁 → 写 defconfig → 生成 .config 并校验”跑完，专门验证上游补丁（susfs / lz4 / droidspaces / CVE）还能不能套在 6.6.118 上；失败点会明确指向是哪一块补丁。

### 3.2 正式构建

同样入口，`verify_only` = false：

| 输入 | 建议 |
| --- | --- |
| `ksu_type` | `bakasu`（默认，兼容 SukiSU 管理器） |
| `susfs_enable` | `true` |
| `lz4_enable` | 第一次建议 **false**（见 $5 风险），确认能开机后再开 |
| `lz4kd_enable` | 保持 false，且与 `lz4_enable` 二选一 |
| `better_net` / `bbr_enable` | 默认关；要 ipset/iptables 再开（已自动剔除 BPF_STREAM_PARSER） |
| `kernel_suffix` | **留空**，留空才会用官方 KMI 串 |
| `droidspaces_enable` / `adios_enable` / `rekernel_enable` / `baseband_guard` | 按需 |

产物：`AnyKernel3_MT6991_6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k.zip`（Release 里也会挂一份）。

### 3.3 OTA 升级之后

OPPO 每次 OTA 可能换 GKI build id（`abogki…` 那段）。升级后先跑：

`~bash
ADB=/绝对路径/adb ADB_SERIAL=127.0.0.1:15555 ./tools/kmi-info.sh
`~

把输出的三行（`KERNEL_NAME` / `SUB_VERSION` / `source_branch`）改到 workflow 的 `env` 与 `inputs` 默认值里，再跑一次。版本串对不上时，CI 会在“校验产物”那步直接失败，不会给你一个装上去工具判定异常的包。

---

## 4. 刷入、验证、回滚

### 刷之前

1. `boot` 分区**必须**先备份（KernelFlasher / HorizonKernelFlasher 都有“备份 boot”按钮）。
2. 当前是 **KernelSU LKM 模式**（内核里的 `kernelsu` 是模块加载的）。刷内置 KSU 的内核前，先在 KernelSU 管理器里把 LKM 卸载/还原，否则会出现“两份 KSU”抢同一个接口。
3. 确认当前槽位是 `_a`（`getprop ro.boot.slot_suffix`），AnyKernel3 会自己处理。

### 刷之后自检（3 条命令）

`~bash
adb shell uname -r                                   # 应等于 6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k
adb shell 'lsmod | wc -l'                            # 官方是 707 上下，明显变少说明模块没加载
adb shell 'dmesg | grep -iE "disagrees about version|Unknown symbol|version magic"'   # 应为空
`~

再肉眼过一遍：相机、WiFi、蓝牙、通话、指纹。

### 回滚

`fastboot flash boot <备份的boot.img>`（或 KernelFlasher 恢复），重启即可；不动 `vendor_dlkm`，不会因为内核回滚导致模块缺失。

---

## 5. 已知风险 / 边界

1. **符号 CRC 是唯一硬门槛**。增加 CONFIG 与补丁都可能改变导出符号 CRC，最典型的是 lz4/zstd 补丁会改动 `zstd_*` 导出符号，官方 `oplus_bsp_zstdn.ko` 可能因此加载失败。所以第一次建议 `lz4_enable=false`，确认基线能开机后再逐项加。
2. 本适配**未在本地编译验证**（按你的要求不在本机跑编译）。CI 里加了硬校验，但“能不能开机”只能刷了才知道——备份 boot 是硬要求。
3. `verify_only=true` 只验证补丁/配置，不验证编译；补丁能套上不代表能编过，上游 KernelSU/susfs 的行为随时可能变（仓库里已有“补丁半套导致 init.c 编译失败”的前科，见提交 `d443d0d`）。
4. Android 17 的 ROM 与 `b_16.0.0`（标称 Android 16）源码之间，内核版本同为 6.6.118，但不能 100% 保证 ROM 侧没有额外内核补丁；若刷入后个别 vendor 模块报 CRC 不一致，按 $4 回滚即可。

---

## 6. 与仓库里其它 workflow 的关系

- 本 workflow **独立**，不改动 `fastbuild_6.6.50.yml` / `fastbuild_6.6.89_mtk.yml` / `fastbuild_6.6.118.yml` / `fastbuild_6.6.118_mtk_noroot.yml`。
- 旧的天玑 workflow 把 `KERNEL_NAME` 写成了 SM8750 的值（`…g29d86c5fc9dd-abogki428889875-4k`），编出来的 `uname -r` 会是一加 13 的串。按 $1 的分析，这**不会**让模块加载失败（版本前缀被忽略），但工具/日志里会显示成别的机型，属于该修的脏数据——本 workflow 已按本机实测值改正。
