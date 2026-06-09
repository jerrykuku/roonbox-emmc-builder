# Roonbox eMMC Builder

[English](./README.md) | [简体中文](./README.zh-CN.md)

把原版 `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` 转换成支持 eMMC 的 Roon ROCK 镜像。

## 这个项目解决什么问题

原版 Roon ROCK 恢复镜像主要按 SATA/NVMe 存储路径设计，很多带 eMMC 的 x86 设备在安装阶段无法被正确识别。
这个项目会重建恢复环境和已安装系统使用的内核，修补安装器与用户态脚本，并重新封装镜像，让 eMMC 设备能够被识别并作为安装目标使用。

## 功能

脚本会自动完成下面这些工作：

- 解包原版恢复镜像
- 提取原版外层 `5.15.72` 和内层 `6.6.33` 内核的 `IKCONFIG`
- 基于原厂配置重编译两套内核
- 为安装器 `initramfs` 增加 `mmcblk*` 识别
- 为已安装系统的 `rootfs.img` 增加 `mmcblk` 用户态支持
- 回封 `install-os.tar`
- 回写新的 `bzImage.efi`、`initramfs`、`install-os.tar`
- 生成新的 `.img`、`.img.gz` 和 `.sha256`

## 项目结构

- `build-image.sh`: 主脚本
- `dist/`: 本地构建产物目录，不提交到 GitHub

## 依赖

需要这些基础工具：

- `bash`
- `curl`
- `xz`
- `fdisk`
- `cpio`
- `bzip2`
- `tar`
- `gzip`
- `mcopy`、`mdir`
- `unsquashfs`
- `mksquashfs`
- `make`
- `perl`
- `grep`
- `strings`

还需要完整的内核编译环境，例如编译器、链接器和常见 kernel build 依赖。

## 快速开始

在仓库目录中直接执行：

```bash
cd roonbox-emmc-builder
./build-image.sh
```

直接从 Roon 官方地址下载原版镜像并构建：

```bash
./build-image.sh --download-official
```

默认输入镜像：

```text
../roonbox-linuxx64-nuc4-usb-factoryreset.img.gz
```

默认输出目录：

```text
./dist/
```

默认输出文件名会保持原版镜像的基础名称，并追加 `-emmc`：

```text
./dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc.img
./dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc.img.gz
```

## 常用命令

指定输入镜像和输出前缀：

```bash
./build-image.sh \
  --input /path/to/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

从 Roon 官方地址下载并输出到自定义前缀：

```bash
./build-image.sh \
  --download-official \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

如果需要改用自定义官方下载地址：

```bash
./build-image.sh \
  --download-official \
  --official-url https://download.roonlabs.net/builds/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

如果两套内核已经构建过，只想快速重打包镜像：

```bash
./build-image.sh --fast
```

## 参数

```text
--official-url <url>    指定官方镜像下载地址
--workdir <path>        指定临时工作目录
--kernel-root <path>    指定内核源码缓存目录
--dist-dir <path>       指定输出目录
--jobs <n>              指定内核编译并行度
--download-official     构建前先从 Roon 官方地址下载镜像
--fast                  跳过内核提取和编译，直接复用 dist/ 中缓存好的内核与配置
--keep-work             保留中间工作目录
--force-rebuild         强制重编两套内核
```

## 输出内容

脚本成功后通常会生成：

- `*.img`
- `*.img.gz`
- `*.sha256`
- 基于原厂配置重建的两份内核
- 两份最终 `.config`

## 容量说明

安装器现在会根据 eMMC 容量自适应调整分区大小：

- 约 43 GiB 及以上：`16 GiB + 16 GiB + 剩余`
- 约 22 GiB 及以上：`8 GiB + 8 GiB + 剩余`
- 约 12 GiB 及以上：`4 GiB + 4 GiB + 剩余`
- 小于约 12 GiB：直接判定容量过小，不支持安装

## 已测试设备

下面这些设备已经实际测试通过，可使用本项目生成的 eMMC 版镜像完成安装与启动：

<table>
  <tr>
    <td align="center" width="50%">
      <a href="https://shop.zimaspace.com/collections/zima-products-family/products/zimaboard-832-2021-special-edition">
        <img src="https://shop.zimaspace.com/cdn/shop/products/zimaboard-832-2021-special-edition-186318.jpg?v=1702679896" alt="ZimaBoard 832" width="320">
      </a>
      <br>
      <strong>ZimaBoard 832</strong>
      <br>
      Intel Celeron N3450 · 8 GB RAM · 32 GB eMMC
      <br>
      测试结果：ROCK 安装和启动均已确认正常
      <br>
      <a href="https://shop.zimaspace.com/collections/zima-products-family/products/zimaboard-832-2021-special-edition">购买链接 / 产品页面</a>
    </td>
    <td align="center" width="50%">
      <a href="https://shop.zimaspace.com/products/zimaboard2-single-board-server">
        <img src="https://shop.zimaspace.com/cdn/shop/files/ZimaBoard_2_home_server_match_week_bonus.png?v=1780918624" alt="ZimaBoard2 832" width="320">
      </a>
      <br>
      <strong>ZimaBoard2 832</strong>
      <br>
      Intel Processor N150 · 8 GB RAM · 32 GB eMMC
      <br>
      测试结果：ROCK 安装和启动均已确认正常
      <br>
      <a href="https://shop.zimaspace.com/products/zimaboard2-single-board-server">购买链接 / 产品页面</a>
    </td>
  </tr>
</table>

## 限制

- 这个项目面向 `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` 这一类特定的 Roon ROCK 恢复镜像结构
- 当前内核改动主要覆盖 x86 平台常见的 `MMC/SDHCI/CQHCI` 路径
- 容量过小的 eMMC 设备不在支持范围内
- 构建产物和重建出来的内核默认不会提交到 git

## License

This project is distributed under the GNU General Public License Version 3.
