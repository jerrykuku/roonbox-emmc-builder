# Roonbox eMMC Builder

[English](./README.md) | [简体中文](./README.zh-CN.md)

Convert the original `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` into a Roon ROCK image with eMMC support.

## Why

The stock Roon ROCK recovery image assumes SATA/NVMe-style storage and does not properly support many eMMC-based x86 devices.
This project rebuilds the recovery and installed kernels, patches the installer and userspace scripts, and repacks the image so eMMC devices can be detected and used as install targets.

## Features

The script automates the full workflow:

- Unpack the original recovery image
- Extract `IKCONFIG` from the original outer `5.15.72` kernel and inner `6.6.33` kernel
- Rebuild both kernels from the vendor configuration baseline
- Add `mmcblk*` detection to the installer `initramfs`
- Add `mmcblk` userspace support to the installed system `rootfs.img`
- Repack `install-os.tar`
- Replace `bzImage.efi`, `initramfs`, and `install-os.tar`
- Generate a new `.img`, `.img.gz`, and `.sha256`

## Project Layout

- `build-image.sh`: main build script
- `dist/`: local build artifacts, not committed to GitHub

## Requirements

Required tools:

- `bash`
- `curl`
- `xz`
- `fdisk`
- `cpio`
- `bzip2`
- `tar`
- `gzip`
- `mcopy`, `mdir`
- `unsquashfs`
- `mksquashfs`
- `make`
- `perl`
- `grep`
- `strings`

You also need a working kernel build environment, including compiler, linker, and common kernel build dependencies.

## Quick Start

Run from the repository directory:

```bash
cd roonbox-emmc-builder
./build-image.sh
```

Download the original image directly from Roon and build from it:

```bash
./build-image.sh --download-official
```

Default input image:

```text
../roonbox-linuxx64-nuc4-usb-factoryreset.img.gz
```

Default output directory:

```text
./dist/
```

Default output file naming keeps the original image basename and appends `-emmc`:

```text
./dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc.img
./dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc.img.gz
```

## Common Usage

Specify input image and output prefix:

```bash
./build-image.sh \
  --input /path/to/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

Download from the official Roon URL and write to a custom output prefix:

```bash
./build-image.sh \
  --download-official \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

Download from a custom official mirror URL:

```bash
./build-image.sh \
  --download-official \
  --official-url https://download.roonlabs.net/builds/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

If the kernels are already cached and you only want to rebuild the image quickly:

```bash
./build-image.sh --fast
```

## Options

```text
--official-url <url>    Set the official Roon image URL
--workdir <path>        Set the temporary working directory
--kernel-root <path>    Set the kernel source cache directory
--dist-dir <path>       Set the output directory
--jobs <n>              Set parallel build jobs
--download-official     Download the official image from Roon before building
--fast                  Skip kernel extraction/build and reuse cached kernels and configs in dist/
--keep-work             Keep the temporary working directory
--force-rebuild         Force rebuilding both kernels
```

## Outputs

Successful runs typically produce:

- `*.img`
- `*.img.gz`
- `*.sha256`
- Two rebuilt kernels based on the original vendor config
- Two final `.config` files

## Capacity Notes

The installer uses adaptive partition sizing for smaller eMMC devices:

- about 43 GiB and above: `16 GiB + 16 GiB + remaining`
- about 22 GiB and above: `8 GiB + 8 GiB + remaining`
- about 12 GiB and above: `4 GiB + 4 GiB + remaining`
- below about 12 GiB: installation is rejected as too small

## Tested Hardware

The following devices have been tested successfully with the generated eMMC-enabled image:

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
      Tested: ROCK install and boot confirmed
      <br>
      <a href="https://shop.zimaspace.com/collections/zima-products-family/products/zimaboard-832-2021-special-edition">Buy / Product Page</a>
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
      Tested: ROCK install and boot confirmed
      <br>
      <a href="https://shop.zimaspace.com/products/zimaboard2-single-board-server">Buy / Product Page</a>
    </td>
  </tr>
</table>

## Limitations

- This project targets the specific Roon ROCK factory-reset image layout used by `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz`
- The current kernel changes focus on x86 eMMC paths such as `MMC/SDHCI/CQHCI`
- Very small eMMC devices are not supported
- Build output images and rebuilt kernels are intentionally kept out of git

## License

This project is distributed under the GNU General Public License Version 3.
