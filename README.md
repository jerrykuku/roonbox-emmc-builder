# Roonbox eMMC Builder

这个目录是一个独立小项目，用来把原版 `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` 一次性转换成支持 eMMC 的 ROCK 镜像。

## 它会做什么

执行主脚本后，会自动完成下面这些步骤：

- 解包原版恢复镜像
- 从原版外层 `5.15.72` 和内层 `6.6.33` 内核提取 `IKCONFIG`
- 基于原厂配置重编译两套内核
- 为安装器 `initramfs` 增加 `mmcblk*` 识别
- 为已安装系统的 `rootfs.img` 增加 `mmcblk` 用户态支持
- 回封 `install-os.tar`
- 回写新的外层 `bzImage.efi`、`initramfs`、`install-os.tar`
- 生成新的 `.img`、`.img.gz` 和 `sha256`

## 目录说明

- `build-image.sh`: 主脚本
- `dist/`: 本地构建产物输出目录，不提交到 GitHub

## 依赖

主机需要具备这些工具：

- `bash`
- `curl`
- `xz`
- `fdisk`
- `cpio`
- `bzip2`
- `tar`
- `gzip`
- `mtools` 里的 `mcopy`、`mdir`
- `unsquashfs`
- `mksquashfs`
- `make`
- `perl`
- `rg`
- `strings`

还需要能编译内核的基本环境，比如编译器、链接器和常见的 kernel build 依赖。

## 用法

最简单的执行方式：

```bash
cd /home/edwin/pkgbuild/roonbox-emmc-builder
./build-image.sh
```

默认输入镜像是：

```text
/home/edwin/pkgbuild/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz
```

默认输出会写到：

```text
/home/edwin/pkgbuild/roonbox-emmc-builder/dist/
```

也可以手动指定输入和输出前缀：

```bash
./build-image.sh \
  --input /home/edwin/pkgbuild/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /home/edwin/pkgbuild/roonbox-emmc-builder/dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

如果两套内核已经构建过，只想快速重打包镜像，可以使用：

```bash
./build-image.sh --fast
```

## 可选参数

```text
--workdir <path>        指定临时工作目录
--kernel-root <path>    指定内核源码缓存目录
--dist-dir <path>       指定输出目录
--jobs <n>              指定内核编译并行度
--fast                  跳过内核提取和编译，直接复用 dist/ 中缓存好的内核与配置
--keep-work             保留中间工作目录
--force-rebuild         强制重编两套内核
```

## 输出结果

脚本成功后通常会生成：

- `*.img`
- `*.img.gz`
- `*.sha256`
- 基于原厂配置重建的两份内核
- 两份最终 `.config`

## 备注

- 目前默认启用的是更适合这类 x86 ROCK 设备的 `MMC/SDHCI/CQHCI` 路线
- `dw_mmc` 没有默认启用，因为这两套原厂 x86 内核树里的该驱动主要受 `ARM/ARM64/...` 或 `COMPILE_TEST` 约束，不适合作为这份镜像的正式运行配置

## License

This project is distributed under the GNU General Public License Version 3.
