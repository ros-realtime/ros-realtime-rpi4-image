Raspberry Pi image with ROS2 and the real-time kernel
=====================================================

[![Build image](https://github.com/ros-realtime/ros-realtime-rpi4-image/actions/workflows/build.yml/badge.svg)](https://github.com/ros-realtime/ros-realtime-rpi4-image/actions/workflows/build.yml)

This repo builds a Raspberry Pi 3/4/400 image with ROS2 and the real-time kernel
pre-installed.  This image can be downloaded directly from [the releases
page](https://github.com/ros-realtime/ros-realtime-rpi4-image/releases),
flashed to a SD card, and booted on a Raspberry Pi 3/4/400.

How to
------

Before you start, you need a SD card that is at least 8GB in size.

1. Download the desired image from [the releases page](https://github.com/ros-realtime/ros-realtime-rpi4-image/releases).
2. The image is compressed with the `xz` compression format. You will need to
   decompress it. On Windows, try using [7-zip](https://www.7-zip.org/) to do
   this if your file archiver doesn't decompress this format already. Once
   decompressed, you should have a file that ends with the extension `.img`.
    1. On Mac/Linux, use `xz --decompress file.img.xz` in the command line.
3. The easiest way to flash the image is via the [Raspberry Pi imager](https://www.raspberrypi.com/software/). 
    1. Using the Raspberry Pi Image, click `CHOOSE OS`.
    2. Scroll all the way down and click `Use custom`.
    3. Browse and select the image file.
    4. Select the storage device.
    5. Click `Write` to flash the image.
    6. Wait for it to be done.
4. Unplug the SD card and plug it into the Raspberry Pi 3/4/400. Turn on the
   Raspberry Pi.
5. The default username is `ubuntu` and the password is `ubuntu`. The default
   hostname is `ubuntu`. You can login either directly on the Raspberry Pi or
   via SSH (enabled by default). You'll need to change your password the first
   time you login.
6. To save space, the image does not have the desktop environment installed. If
   you want a desktop environment, you must install it with the following three
   commands:

```
sudo apt update && sudo apt upgrade
sudo apt install ubuntu-desktop
sudo apt install ros-humble-desktop
```

7. You can now use ROS. To confirm, type `ros2` into the terminal. You should
   see:

```
usage: ros2 [-h] [--use-python-default-buffering] Call `ros2 <command> -h` for more detailed usage. ...

ros2 is an extensible command-line tool for ROS 2.

options:
  -h, --help            show this help message and exit

  [...omitted for brevity]
```

8. The setup is now complete! 🎉 You can follow the rest of the [ROS2 tutorials
   here](https://docs.ros.org/en/humble/Tutorials.html).

Bonus setup
-----------

- [Setup WiFi without a GUI](https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi#3-wifi-or-ethernet).
- [Overclocking the CPU](https://magpi.raspberrypi.com/articles/how-to-overclock-raspberry-pi-4).
  I've had good luck with `arm_freq=2000` and `over_voltage=6` when using power
  supplies that can consistently output 5V/3A (like the official power supply).
- Try out real-time programming with the following resources:
  - [(1)](https://docs.ros.org/en/humble/Tutorials/Demos/Real-Time-Programming.html), [(2)](https://ros-realtime.github.io/Resources/resources.html), [(3)](https://shuhaowu.com/blog/2022/01-linux-rt-appdev-part1.html), [(4)](https://wiki.linuxfoundation.org/realtime/documentation/howto/applications/start)

The rest of this README is meant for developers who want to know more about the
image builder.

Custom Image Builder for the Raspberry Pi for ROS2 + PREEMPT_RT
===============================================================

This is a custom image builder for the Raspberry Pi 4. Some features:

- Customize the official Ubuntu server image for the Raspberry Pi by mounting
  it locally (via loop device) and chrooting into it (via systemd-nspawn and
  qemu-user-static).
  - I can't locate how Canonical generate the official Ubuntu images for the
    Raspberry Pi, so I had to resort to this method.
  - The default customization in this repo is made for ROS2 with `PREEMPT_RT`
    applied.
- With two stages of setup scripts, executing in lock step both inside and
  outside the chroot, we can cross compile code (via something like CMake
  toolchain) on the host and copy it into the chroot for making the final
  image.
- One thing we all hate while building images is to waste a lot of time. These
  scripts are designed to hopefully not waste your time. It has several
  features for this:
  - The build process is divided into resumable steps. This means there is no
    need (in most cases) to restart the build from scratch if you make a
    mistake. You can experiment with the image as it builds either by
    deliberately pausing the build process after a certain step or be forced to
    pause because there are some typos in the build scripts.
  - Nice logs that aids with debugging of the build, should things go wrong.
  - Use tools like `pv` to display progress when applicable.
- The features of the actual RT image is difficult to document without becoming
  out of date quickly. Please take a look at `focal-rt-ros2/ros2/rootfs/setup/phase1.sh`
  for the setup script that runs against the Ubuntu image and `focal-rt-ros2/rootfs`
  for files that gets overlaid on top of the Ubuntu image. That said, some basics are:
  - Installed [`PREEMPT_RT` kernel](https://github.com/ros-realtime/rt-kernel-docker-builder).
  - Pinned CPU frequency and performance governor.
  - Removed some unnecessary services like snapd and fwupd to save resources.
  - Installed ROS2 galactic from apt.
  - Installed some misc. tooling (like `vcgencmd`).

### Todos

- [ ] Optionally configure isolcpus and nohz_full for the kernel.
- [ ] Use a sha256 checksum to ensure downloaded image and kernel are "secure".
- [ ] Add overclocking support

How to use
----------

### System requirements

**Why not docker?** Unfortunately, the current setup doesn't work in Docker, as 
I used `systemd-nspawn` to make setting up and executing commands in a chroot easier
(mainly so I can save some time figuring out the various bind mounts I need, to
shutdown the container correctly if a command fails, and to force quit a
container if something goes really wrong by pressing ^] 3 times).  This tool
also rely on loop devices, which are not namespaced and thus not readily usable
in Docker without privileged access. It may be possible to use Docker later by
changing this code, but for now it's not possible (the code will also likely be
uglier as nspawn can't be easily used in docker?).

Thus, you'll need a Linux machine with root and the following tools installed:
`cut`, `grep`, `parted`, `pv`, `rsync`, `truncate`, `wget`, `systemd-nspawn`,
and `qemu-aarch64-static`.

You will also need `python3`.

To build the `focal-rt-ros2` image, you'll also need: `zip`.

For Ubuntu, you can simply run:

```
$ sudo apt install parted pv rsync wget systemd-container qemu-user-static make zip
```

### To run

1. Build the image
  - To build the Ubuntu 22.04 + ROS Humble image: `make jammy-rt-ros2`.
  - To build the Ubuntu 20.04 + ROS Galactic image: `make focal-rt-ros2`.
2. Take the image in the `out` folder and `dd` it into an SD card (or flash it
   in another way).

### Cross compilation

There are two ways to use cross-compilation with this system:

1. In the image build process, cross-compile and install some applications
   (_phase2 cross-compile_). See the [customization guide for more
   details](docs/BuilderDesignAndUsageGuide.md).
2. After the image is built, re-mount it and then cross-compile other projects
   in an adhoc/interactive manner (_interactive cross-compile_). This section
   talks about this use case.


To cross-compile, you'll need to install this builder on the host machine via setuptools:

```
[host]$ sudo python3 setup.py install
```

Make sure the built image is mounted by running the following command in the
same directory where you built the image. This will also create a file called
`cache/loop-device.txt` that records which loop device is used to mount the
image.

```
[host]$ sudo ros-rt-img mount out/ubuntu-22.04.1-rt-ros2-arm64+raspi.img
```

This will mount the image at `/tmp/rpi4-image-build`. At this point, you might
need to install dependencies into this image before you can build and link your
application. To do this, first enter the container:

```
[host]$ sudo ros-rt-img chroot
```

Then install any dependencies you want:

```
[rpi4image]# sudo apt install libboost-dev # An example
```

Note, this changes the built img file. So either you want to create a backup if
you want the pristine copy (or alternatively, use the phase2 cross-compile
instead).

This project provides a [cmake toolchain
file](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html) and
its absolute is printed when you run the command `ros-rt-img toolchain`. To use
this file with cmake, make sure you have the cross-compiler installed on your
host machine, then configure your project and build via the following commands:

```
[host]$ sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
[host]$ cd <project path>
[host]$ cmake -Bbuild -DCMAKE_TOOLCHAIN_FILE=$(ros-rt-img toolchain)
[host]$ cmake --build build -j $(nproc)
```

The targets built can then be copied to the Raspberry Pi (via SSH, or other
means), where it can then run.

To unmount the img, run the following command in the same directory where you
mounted it originally (where it originally created the `cache/loop-device.txt`
file):

```
$ sudo ros-rt-img umount
```

Customization guide
-------------------

See [`docs/BuilderDesignAndUsageGuide.md`](docs/BuilderDesignAndUsageGuide.md).
