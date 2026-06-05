# Roonbox eMMC Builder

[English](./README.md) | [简体中文](./README.zh-CN.md)

把原版 `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` 转换成支持 eMMC 的 Roon ROCK 镜像。

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
- `rg`
- `strings`

还需要完整的内核编译环境，例如编译器、链接器和常见 kernel build 依赖。

## 快速开始

在仓库目录中直接执行：

```bash
cd roonbox-emmc-builder
./build-image.sh
```

默认输入镜像：

```text
../roonbox-linuxx64-nuc4-usb-factoryreset.img.gz
```

默认输出目录：

```text
./dist/
```

## 常用命令

指定输入镜像和输出前缀：

```bash
./build-image.sh \
  --input /path/to/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

如果两套内核已经构建过，只想快速重打包镜像：

```bash
./build-image.sh --fast
```

## 参数

```text
--workdir <path>        指定临时工作目录
--kernel-root <path>    指定内核源码缓存目录
--dist-dir <path>       指定输出目录
--jobs <n>              指定内核编译并行度
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

## License

This project is distributed under the GNU General Public License Version 3.
